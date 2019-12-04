resource "azurerm_resource_group" "rg" {
  name     = "${var.resource_group}"
  location = "${var.azurerm_location}"
}

data "azurerm_availability_set" "availability_set" {
  name = "availability_set1"
  resource_group_name = "${azurerm_resource_group.rg.name}"
}

resource "azurerm_virtual_network" "vn" {
  name = "${var.virtual_network_name}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location = "${azurerm_resource_group.rg.location}"
  address_space = ["${var.add_space}"]
}

resource "azurerm_subnet" "subnet1" {
  name = "subnet1"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  virtual_network_name = "${azurerm_virtual_network.vn.name}"
  address_prefix = "${var.subnet1_add_prefix}"
}

resource "azurerm_subnet" "subnet2" {
  name = "subnet2"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  virtual_network_name = "${azurerm_virtual_network.vn.name}"
  address_prefix = "${var.subnet2_add_prefix}"
}

resource "azurerm_subnet" "AzureFirewallSubnet" {
  name = "AzureFirewallSubnet"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  virtual_network_name = "${azurerm_virtual_network.vn.name}"
  address_prefix = "${var.subnet3_add_prefix}"
}

resource "azurerm_public_ip" "webapp-pip" {
  name                = "${var.prefix}-ip"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall" "webapp-firewall" {
  name                = "testfirewall"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  ip_configuration {
    name                 = "configuration"
    subnet_id            = "${azurerm_subnet.AzureFirewallSubnet.id}"
    public_ip_address_id = "${azurerm_public_ip.webapp-pip.id}"
  }
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
subnet1
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

  security_rule {
    name                       = "lb-outbound"
    priority                   = 101
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

}

resource "azurerm_network_security_group" "database-sg" {
  name                = "${var.prefix}-database-sg"
  location            = "${var.azurerm_location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

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

resource "azurerm_lb_nat_pool" "lbnatpool" {
  resource_group_name = "${azurerm_resource_group.rg.name}"
  loadbalancer_id = "${azurerm_lb.webapp-lb.id}"
  name = "ssh"
  protocol = "Tcp"
  frontend_port_start = 1
  frontend_port_end = 65534
  backend_port = 22
  frontend_ip_configuration_name = "frontend"
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

resource "azurerm_route_table" "public_rt" {
  name = "routeTable"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location = "${azurerm_resource_group.rg.location}"
}

resource "azurerm_route" "route" {
  name = "route1"
  resource_group_name = azurerm_resource_group.rg.name
  route_table_name = azurerm_route_table.public_rt.name
  address_prefix = "10.1.0.0/16"
  next_hop_type = "VnetLocal"
}

resource "azurerm_subnet_route_table_association" "subnet1_route_table" {
  subnet_id = azurerm_subnet.subnet1.id
  route_table_id = azurerm_route_table.public_rt.id
}

resource "azurerm_subnet_route_table_association" "subnet2_route_table" {
  subnet_id = azurerm_subnet.subnet2.id
  route_table_id = azurerm_route_table.public_rt.id
}

//resource "azurerm_subnet_route_table_association" "subnet3_route_table" {
//  subnet_id = azurerm_subnet.subnet3.id
//  route_table_id = azurerm_route_table.public_rt.id
//}

resource "azurerm_app_service_plan" "asp"{
  name = "AppServiceplan"
  location = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  sku {
    tier = "Standard"
    size = "S1"
  }
}

resource "azurerm_app_service" "as"{
  name = "AppService"
  location = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  app_service_plan_id = "${azurerm_app_service_plan.asp.id}"
}

resource "azurerm_app_service_slot" "ass"{
  name = "AppServiceSlot"
  location = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  app_service_plan_id = "${azurerm_app_service_plan.asp.id}"
  app_service_name = "${azurerm_app_service.as.name}"
}

#Autoscaling

resource "azurerm_virtual_machine_scale_set" "vm_autoscaling" {
  name                = "autoscaling"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

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
      subnet_id = "${azurerm_subnet.subnet1.id}"
      load_balancer_backend_address_pool_ids = ["${azurerm_lb_backend_address_pool.webapp-lb-backend.id}"]
      load_balancer_inbound_nat_rules_ids = ["${azurerm_lb_nat_pool.lbnatpool.id}"]
    }
  }

  tags = {
    environment = "staging"
  }
}

#Autoscale monitoring alert
resource "azurerm_autoscale_setting" "monitor_as"{
  name = "Monitor_autoscale"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location = "${azurerm_resource_group.rg.location}"
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
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  application_type    = "Node.JS"
}

#for notification
resource "random_integer" "ri1" {
  min = 10000
  max = 99999
}


resource "azurerm_storage_account" "sae" {
  name                     = "sae${random_integer.ri1.result}"
  resource_group_name      = "${azurerm_resource_group.rg.name}"
  location                 = "${azurerm_resource_group.rg.location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_queue" "sq" {
  name = "storage-queue"
  resource_group_name      = "${azurerm_resource_group.rg.name}"
  storage_account_name = "${azurerm_storage_account.sae.name}"
}

resource "azurerm_eventgrid_topic" "egt"{
  name = "evengrid_topic"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  tags = {
    environment = "eventgrid_topic"
  }
}

resource "azurerm_eventgrid_event_subscription" "egs" {
  name = "evengrid_subscription"
  scope = "${azurerm_resource_group.rg.id}"
  topic_name = "${azurerm_eventgrid_topic.egt.name}"

  storage_queue_endpoint {
    storage_account_id = "${azurerm_storage_account.sae.id}"
    queue_name = "${azurerm_storage_queue.sq.name}"
  }
}



output "rg_name" {
  value = "${azurerm_resource_group.rg.name}"
}

output "rg_location" {
  value = "${azurerm_resource_group.rg.location}"
}

output "vn_id" {
  value = azurerm_virtual_network.vn.id
}

output "subnet_id1" {
  value = azurerm_subnet.subnet1.id
}

output "subnet_id2" {
  value = azurerm_subnet.subnet2.id
}

output "subnet_id3" {
  value = azurerm_subnet.AzureFirewallSubnet.id
}