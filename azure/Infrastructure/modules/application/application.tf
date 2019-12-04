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
  name                      = "csye6225-projectfunc"
  location                  = "${var.rg_location}"
  resource_group_name       = "${var.rg_name}"
  app_service_plan_id       = "${azurerm_app_service_plan.asp.id}"
  storage_connection_string = "${azurerm_storage_account.functionsa-demo.primary_connection_string}"
}

resource "azurerm_network_security_group" "database-sg" {
  name                = "${var.prefix}-database-sg"
  location            = "${var.rg_location}"
  resource_group_name = "${var.rg_name}"

  security_rule {
    name                       = "dbRule"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "webapp-pip-lb" {
  name                = "${var.prefix}-ip-lb"
  location            = "${var.rg_location}"
  resource_group_name = "${var.rg_name}"
  allocation_method   = "Static"
}

resource "azurerm_lb" "webapp-lb" {
  name                = "${var.prefix}-lb"
  location            = "${var.rg_location}"
  resource_group_name = "${var.rg_name}"

  frontend_ip_configuration {
    name                 = "frontend"
    public_ip_address_id = "${azurerm_public_ip.webapp-pip-lb.id}"
  }
}

resource "azurerm_lb_backend_address_pool" "webapp-lb-backend" {
  resource_group_name = "${var.rg_name}"
  loadbalancer_id     = "${azurerm_lb.webapp-lb.id}"
  name                = "BackEndAddressPool"
  depends_on      = [azurerm_lb.webapp-lb]
}

resource "azurerm_lb_nat_pool" "lbnatpool" {
  resource_group_name = "${var.rg_name}"
  loadbalancer_id = "${azurerm_lb.webapp-lb.id}"
  name = "ssh"
  protocol = "Tcp"
  frontend_port_start = 1
  frontend_port_end = 65534
  backend_port = 22
  frontend_ip_configuration_name = "frontend"
}

resource "azurerm_lb_probe" "azlb-probe" {
  resource_group_name = "${var.rg_name}"
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
  resource_group_name            = "${var.rg_name}"
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

resource "azurerm_app_service_plan" "asp1"{
  name = "AppServiceplan"
  location = "${var.rg_location}"
  resource_group_name = "${var.rg_name}"
  sku {
    tier = "Standard"
    size = "S1"
  }
}

resource "azurerm_app_service" "as"{
  name = "csye6225-appService"
  location = "${var.rg_location}"
  resource_group_name = "${var.rg_name}"
  app_service_plan_id = "${azurerm_app_service_plan.asp1.id}"
}

resource "azurerm_app_service_slot" "appslot"{
  name = "AppServiceSlot"
  location = "${var.rg_location}"
  resource_group_name = "${var.rg_name}"
  app_service_plan_id = "${azurerm_app_service_plan.asp1.id}"
  app_service_name = "${azurerm_app_service.as.name}"
}

#Autoscaling

resource "azurerm_virtual_machine_scale_set" "vm_autoscaling" {
  name                = "autoscaling"
  location            = "${var.rg_location}"
  resource_group_name = "${var.rg_name}"

  # automatic rolling upgrade
  automatic_os_upgrade = true
  upgrade_policy_mode  = "Rolling"

  rolling_upgrade_policy {
    max_batch_instance_percent              = 20
    max_unhealthy_instance_percent          = 20
    max_unhealthy_upgraded_instance_percent = 5
    pause_time_between_batches              = "PT0S"
  }

  # required when using rolling upgrade policy
  health_probe_id = "${azurerm_lb_probe.azlb-probe.id}"

  sku {
    name     = "Standard_F2"
    tier     = "Standard"
    capacity = 2
  }

  storage_profile_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_profile_os_disk {
    name              = ""
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_profile_data_disk {
    lun           = 0
    caching       = "ReadWrite"
    create_option = "Empty"
    disk_size_gb  = 10
  }

  os_profile {
    computer_name_prefix = "testvm"
    admin_username = "${var.admin_username}"
    admin_password = "${var.admin_password}"
  }

  os_profile_linux_config {
    disable_password_authentication = false

    #ssh_keys {
    #  path     = "/home/harshil/.ssh/authorized_keys"
    #  key_data = "${file("~/.ssh/demo_key.pub")}"
    #}
  }

  network_profile {
    name    = "terraformnetworkprofile"
    primary = true

    ip_configuration {
      name = "TestIPConfiguration"
      primary = true
      subnet_id = "${var.subnet_id1}"
      load_balancer_backend_address_pool_ids = ["${azurerm_lb_backend_address_pool.webapp-lb-backend.id}"]
      load_balancer_inbound_nat_rules_ids = ["${azurerm_lb_nat_pool.lbnatpool.id}"]
    }
  }

  tags = {
    environment = "staging"
  }
}

#Autoscale monitoring alert
resource "azurerm_autoscale_setting" "autoscale"{
  name = "Monitor_autoscale"
  resource_group_name = "${var.rg_name}"
  location = "${var.rg_location}"
  target_resource_id = "${azurerm_virtual_machine_scale_set.vm_autoscaling.id}"

  profile {
    name = "profile"

    capacity {
      default = 1
      minimum = 1
      maximum = 10  
    }

    rule {
      metric_trigger {
        metric_name = "Percentage CPU"
        metric_resource_id = "${azurerm_virtual_machine_scale_set.vm_autoscaling.id}"
        time_grain = "PT1M"
        statistic = "Average"
        time_window = "PT5M"
        time_aggregation = "Average"
        operator = "GreaterThan"
        threshold = 75
      }

      scale_action {
        direction = "Increase"
        type = "ChangeCount"
        value = "1"
        cooldown = "PT1M"
      }
    }

    rule {
      metric_trigger {
        metric_name = "Percentage CPU"
        metric_resource_id = "${azurerm_virtual_machine_scale_set.vm_autoscaling.id}"
        time_grain = "PT1M"
        statistic = "Average"
        time_window = "PT5M"
        time_aggregation = "Average"
        operator = "LessThan"
        threshold = 25
      }

      scale_action {
        direction = "Decrease"
        type = "ChangeCount"
        value = "1"
        cooldown = "PT1M"
      }
    }
  }
}

resource "azurerm_application_insights" "monitor" {
  name                = "appinsights"
  location            = "${var.rg_location}"
  resource_group_name = "${var.rg_name}"
  application_type    = "Node.JS"
}

#for notification
resource "random_integer" "ri1" {
  min = 10000
  max = 99999
}


resource "azurerm_storage_account" "sae" {
  name                     = "sae${random_integer.ri1.result}"
  resource_group_name      = "${var.rg_name}"
  location                 = "${var.rg_location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_queue" "sq" {
  name = "storage-queue"
  resource_group_name      = "${var.rg_name}"
  storage_account_name = "${azurerm_storage_account.sae.name}"
}

resource "azurerm_eventgrid_topic" "egt"{
  name = "csye6225-eventgrid-topic"
  location            = "${var.rg_location}"
  resource_group_name = "${var.rg_name}"

  tags = {
    environment = "eventgrid_topic"
  }
}

resource "azurerm_eventgrid_event_subscription" "egs" {
  name = "evengrid_subscription"
  scope = "${var.rg_id}"
  topic_name = "${azurerm_eventgrid_topic.egt.name}"

  storage_queue_endpoint {
    storage_account_id = "${azurerm_storage_account.sae.id}"
    queue_name = "${azurerm_storage_queue.sq.name}"
  }
}


// resource "azurerm_network_interface" "webapp-nic" {
//   name = "${var.prefix}-nic"
//   resource_group_name = "${var.rg_name}"
//   location = "${var.rg_location}"
//   network_security_group_id = "${azurerm_network_security_group.webapp-sg.id}"

//   ip_configuration {
//     name = "${var.prefix}ipconfig"
//     subnet_id = "${azurerm_subnet.subnet1.id}"
//     private_ip_address_allocation = "Dynamic"
//     public_ip_address_id          = "${azurerm_public_ip.webapp-pip.id}"
//     primary = true
//   }
// }

// resource "azurerm_virtual_machine" "webapp-vm" {
//   name                = "webapp-vm"
//   location            = "${var.rg_location}"
//   resource_group_name = "${var.rg_name}"
//   vm_size             = "${var.vm_size}"
//   network_interface_ids         = ["${azurerm_network_interface.webapp-nic.id}"]
//   delete_os_disk_on_termination = "true"

//   storage_image_reference {
//     publisher = "${var.image_publisher}"
//     offer     = "${var.image_offer}"
//     sku       = "${var.image_sku}"
//     version   = "${var.image_version}"
//   }

//   storage_os_disk {
//     name              = "${var.prefix}-osdisk"
//     managed_disk_type = "Standard_LRS"
//     caching           = "ReadWrite"
//     create_option     = "FromImage"
//   }

//   os_profile {
//     computer_name  = "${var.prefix}-hostname"
//     admin_username = "${var.admin_username}"
//     admin_password = "${var.admin_password}"
//   }

//   os_profile_linux_config {
//     disable_password_authentication = false
//   }
// }

// resource "azurerm_public_ip" "webapp-pip-lb" {
//   name                = "${var.prefix}-ip-lb"
//   location            = "${var.rg_location}"
//   resource_group_name = "${var.rg_name}"
//   allocation_method   = "Static"
// }

// resource "azurerm_lb" "webapp-lb" {
//   name                = "${var.prefix}-lb"
//   location            = "${var.rg_location}"
//   resource_group_name = "${var.rg_name}"

//   frontend_ip_configuration {
//     name                 = "frontend"
//     public_ip_address_id = "${azurerm_public_ip.webapp-pip-lb.id}"
//   }
// }

// resource "azurerm_lb_backend_address_pool" "webapp-lb-backend" {
//   resource_group_name = "${var.rg_name}"
//   loadbalancer_id     = "${azurerm_lb.webapp-lb.id}"
//   name                = "BackEndAddressPool"
//   depends_on      = [azurerm_lb.webapp-lb]
// }

// resource "azurerm_lb_probe" "azlb-probe" {
//   resource_group_name = "${var.rg_name}"
//   loadbalancer_id     = "${azurerm_lb.webapp-lb.id}"
//   name                = "probe-https"
//   port                = "443"
//   protocol            = "Tcp"
//   // name                = "${element(keys(var.lb_port), count.index)}"
//   // protocol            = "${element(var.lb_port["${element(keys(var.lb_port), count.index)}"], 1)}"
//   // port                = "${element(var.lb_port["${element(keys(var.lb_port), count.index)}"], 2)}"
//   //interval_in_seconds = "${var.lb_probe_interval}"
//   //number_of_probes    = "${var.lb_probe_unhealthy_threshold}"
// }

// resource "azurerm_lb_rule" "azlb-rule" {
//   resource_group_name            = "${var.rg_name}"
//   loadbalancer_id                = "${azurerm_lb.webapp-lb.id}"
//   name                           = "recipe-webapp-lbrules"
//   frontend_port                  = "80"
//   frontend_ip_configuration_name = "frontend"
//   backend_address_pool_id        = "${azurerm_lb_backend_address_pool.webapp-lb-backend.id}"
//   backend_port                   = "80"
//   protocol                       = "tcp"
//   enable_floating_ip             = "true"
//   probe_id                       = "${azurerm_lb_probe.azlb-probe.id}"
//   depends_on                     = ["azurerm_lb_probe.azlb-probe"]
// }