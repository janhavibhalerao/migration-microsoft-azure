variable "azurerm_location" {
    description = "Enter azurerm_location. Example (East US) "
    type = string
    default = "East US"
}

variable "virtual_network_name" {
  description = "Enter a valid virtual network name "
  type = string
  default = "testing"
}

variable "add_space" {
  description = "Enter a valid address space. Example (10.x.x.x/16) "
  type = string
  default = "10.0.0.0/16"
}

variable "subnet3_add_prefix" {
  description = "Enter a valid subnet address prefix. Example (10.x.x.x/24) "
  type = string
  default = "10.0.0.3/24"
}

variable "subnet2_add_prefix" {
  description = "Enter a valid subnet address prefix. Example (10.x.x.x/24) "
  type = string
  default = "10.0.0.2/24"
}

variable "subnet1_add_prefix" {
  description = "Enter a valid subnet address prefix. Example (10.x.x.x/24) "
  type = string
  default = "10.0.0.1/24"
}