resource "random_integer" "ri" {
  min = 10000
  max = 99999
}

# Storage for images - Storage blob
resource "azurerm_storage_account" "sa" {
  name                     = "storageaccount${random_integer.ri.result}"
  resource_group_name      = "${var.rg_name}"
  location                 = "${var.rg_location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "BlobStorage"
  access_tier              = "Hot"
}

resource "azurerm_storage_container" "image-container" {
  name                  = "images"
  resource_group_name   = "${var.rg_name}"
  storage_account_name  = "${azurerm_storage_account.sa.name}"
  container_access_type = "private"
}

resource "azurerm_storage_blob" "object-storage" {
  name                   = "content.zip"
  resource_group_name    = "${var.rg_name}"
  storage_account_name   = "${azurerm_storage_account.sa.name}"
  storage_container_name = "${azurerm_storage_container.image-container.name}"
  type                   = "Block"
  #source                 = "local-content.zip"
}

# Storage for data - MySQL
resource "azurerm_mysql_server" "mysql-server-demo" {
  name                = "mysqlserver-${random_integer.ri.result}"
  location            = "${var.rg_location}"
  resource_group_name = "${var.rg_name}"

  sku {
    name     = "B_Gen5_2"
    capacity = 2
    tier     = "Basic"
    family   = "Gen5"
  }

  storage_profile {
    storage_mb            = 5120
    backup_retention_days = 7
    geo_redundant_backup  = "Disabled"
  }

  administrator_login          = "mysqladminun"
  administrator_login_password = "Admin@123"
  version                      = "5.7"
  ssl_enforcement              = "Disabled"
}

resource "azurerm_mysql_database" "mysql-db" {
  name                = "mysqldb"
  resource_group_name = "${var.rg_name}"
  server_name         = "${azurerm_mysql_server.mysql-server-demo.name}"
  charset             = "utf8"
  collation           = "utf8_unicode_ci"
}

# This firewall rule allows database connections from anywhere
resource "azurerm_mysql_firewall_rule" "demo" {
  name                = "tf-guide-demo"
  resource_group_name = "${var.rg_name}"
  server_name         = "${azurerm_mysql_server.mysql-server-demo.name}"
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}

# Storage for token - CosmosDB
resource "azurerm_cosmosdb_account" "cosmos-db" {
    name                = "cosmos-db-${random_integer.ri.result}"
    location            = "${var.rg_location}"
    resource_group_name = "${var.rg_name}"
    offer_type          = "Standard"
    kind                = "GlobalDocumentDB"

    enable_automatic_failover = true

    consistency_policy {
        consistency_level       = "BoundedStaleness"
        max_interval_in_seconds = 301
        max_staleness_prefix    = 100001
    }

    geo_location {
        location          = "West US"
        failover_priority = 1
    }

    geo_location {
        prefix            = "tfex-cosmos-db-${random_integer.ri.result}-customid"
        location          = "${var.rg_location}"
        failover_priority = 0
    }
}

# Azure Functions
resource "azurerm_storage_account" "functionsa-demo" {
  name                     = "functionsa${random_integer.ri.result}"
  resource_group_name      = "${var.rg_name}"
  location                 =  "${var.rg_location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_app_service_plan" "asp" {
  name                = "azure-functions-service-plan"
  location            = "${var.rg_location}"
  resource_group_name = "${var.rg_name}"
  kind                = "FunctionApp"

  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

resource "azurerm_function_app" "function" {
  name                      = "project-func"
  location                  = "${var.rg_location}"
  resource_group_name       = "${var.rg_name}"
  app_service_plan_id       = "${azurerm_app_service_plan.asp.id}"
  storage_connection_string = "${azurerm_storage_account.functionsa-demo.primary_connection_string}"
}



resource "azurerm_network_security_group" "webapp-sg" {
  name                = "${var.prefix}-sg"
  location            = "${var.azurerm_location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  security_rule {
    name                       = "HTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "SSH"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "webapp-nic" {
  name = "${var.prefix}-nic"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location = "${azurerm_resource_group.rg.location}"
  network_security_group_id = "${azurerm_network_security_group.webapp-sg.id}"

  ip_configuration {
    name = "${var.prefix}ipconfig"
    subnet_id = "${azurerm_subnet.subnet1.id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.webapp-pip.id}"
    primary = true
  }
}

resource "azurerm_virtual_machine" "webapp-vm" {
  name                = "webapp-vm"
  location            = "${var.azurerm_location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  vm_size             = "${var.vm_size}"
  network_interface_ids         = ["${azurerm_network_interface.webapp-nic.id}"]
  delete_os_disk_on_termination = "true"

  storage_image_reference {
    publisher = "${var.image_publisher}"
    offer     = "${var.image_offer}"
    sku       = "${var.image_sku}"
    version   = "${var.image_version}"
  }

  storage_os_disk {
    name              = "${var.prefix}-osdisk"
    managed_disk_type = "Standard_LRS"
    caching           = "ReadWrite"
    create_option     = "FromImage"
  }

  os_profile {
    computer_name  = "${var.prefix}-hostname"
    admin_username = "${var.admin_username}"
    admin_password = "${var.admin_password}"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}

resource "azurerm_public_ip" "webapp-pip-lb" {
  name                = "${var.prefix}-ip-lb"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  allocation_method   = "Static"
}

resource "azurerm_lb" "webapp-lb" {
  name                = "${var.prefix}-lb"
  location            = "${var.azurerm_location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  frontend_ip_configuration {
    name                 = "frontend"
    public_ip_address_id = "${azurerm_public_ip.webapp-pip-lb.id}"
  }
}

resource "azurerm_lb_backend_address_pool" "webapp-lb-backend" {
  resource_group_name = "${azurerm_resource_group.rg.name}"
  loadbalancer_id     = "${azurerm_lb.webapp-lb.id}"
  name                = "BackEndAddressPool"
  depends_on      = [azurerm_lb.webapp-lb]
}

resource "azurerm_lb_probe" "azlb-probe" {
  resource_group_name = "${azurerm_resource_group.rg.name}"
  loadbalancer_id     = "${azurerm_lb.webapp-lb.id}"
  name                = "probe-https"
  port                = "443"
  protocol            = "Tcp"
  // name                = "${element(keys(var.lb_port), count.index)}"
  // protocol            = "${element(var.lb_port["${element(keys(var.lb_port), count.index)}"], 1)}"
  // port                = "${element(var.lb_port["${element(keys(var.lb_port), count.index)}"], 2)}"
  //interval_in_seconds = "${var.lb_probe_interval}"
  //number_of_probes    = "${var.lb_probe_unhealthy_threshold}"
}

resource "azurerm_lb_rule" "azlb-rule" {
  resource_group_name            = "${azurerm_resource_group.rg.name}"
  loadbalancer_id                = "${azurerm_lb.webapp-lb.id}"
  name                           = "recipe-webapp-lbrules"
  frontend_port                  = "80"
  frontend_ip_configuration_name = "frontend"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.webapp-lb-backend.id}"
  backend_port                   = "80"
  protocol                       = "tcp"
  enable_floating_ip             = "true"
  probe_id                       = "${azurerm_lb_probe.azlb-probe.id}"
  depends_on                     = ["azurerm_lb_probe.azlb-probe"]
}