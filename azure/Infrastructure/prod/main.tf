provider "azurerm" {
  #version = "=1.36.0"
}

module "networking" {
    source = "../modules/networking"
    virtual_network_name = var.virtual_network_name
    add_space = var.add_space
    subnet1_add_prefix = var.subnet1_add_prefix
    subnet2_add_prefix = var.subnet2_add_prefix
    subnet3_add_prefix = var.subnet3_add_prefix

}
module "application"{
   source = "../modules/application"
}