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
  //name = "AzureFirewallSubnet"
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

// resource "azurerm_subnet_route_table_association" "subnet3_route_table" {
//   subnet_id = azurerm_subnet.AzureFirewallSubnet.id
//   route_table_id = azurerm_route_table.public_rt.id
// }

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