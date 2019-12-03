# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "demorg"
  location = "${var.azurerm_location}"

  tags = {
    environment = "Production"
  }
}

resource "azurerm_virtual_network" "vn" {
  name = "${var.virtual_network_name}"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  address_space = ["${var.add_space}"]
  #dns_servers = ["10.0.0.4", "10.0.0.5"]

  tags = {
      Name = var.virtual_network_name
  }
}

resource "azurerm_subnet" "subnet1" {
  name = "subnet1-name"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  virtual_network_name = "${azurerm_virtual_network.vn.name}"
  address_prefix = "${var.subnet1_add_prefix}"
}

resource "azurerm_subnet" "subnet2" {
  name = "subnet2-name"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  virtual_network_name = "${azurerm_virtual_network.vn.name}"
  address_prefix = "${var.subnet2_add_prefix}"
}

resource "azurerm_subnet" "subnet3" {
  name = "subnet3-name"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  virtual_network_name = "${azurerm_virtual_network.vn.name}"
  address_prefix = "${var.subnet3_add_prefix}"
}

resource "azurerm_route_table" "public_rt" {
  name = "routeTable"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location

  tags = {
    Name = "routeTable"
  }
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

resource "azurerm_subnet_route_table_association" "subnet3_route_table" {
  subnet_id = azurerm_subnet.subnet3.id
  route_table_id = azurerm_route_table.public_rt.id
}

resource "azurerm_network_interface" "network_interface" {
  name = "networkInterface1"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location

  ip_configuration {
    name = "testconfiguration1"
    subnet_id = azurerm_subnet.subnet1.id
    private_ip_address_allocation = "Dynamic"
    primary = true
  }
  tags = {
    environment = "staging"
  }
}

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "resource_group_location" {
  value = azurerm_resource_group.rg.location
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
  value = azurerm_subnet.subnet3.id
}