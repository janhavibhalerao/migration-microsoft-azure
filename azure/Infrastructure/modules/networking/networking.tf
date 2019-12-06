resource "azurerm_resource_group" "rg" {
  name     = "${var.resource_group}"
  location = "${var.azurerm_location}"
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

resource "azurerm_public_ip" "webapp-pip-nic" {
  name                = "${var.prefix}-ip-nic"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  allocation_method   = "Static"
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
    public_ip_address_id          = "${azurerm_public_ip.webapp-pip-nic.id}"
    primary = true
  }
}

// resource "azurerm_virtual_machine" "webapp-vm" {
//   name                = "webapp-vm"
//   location            = "${var.azurerm_location}"
//   resource_group_name = "${azurerm_resource_group.rg.name}"
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

output "rg_name" {
  value = "${azurerm_resource_group.rg.name}"
}

output "rg_id" {
  value = "${azurerm_resource_group.rg.id}"
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