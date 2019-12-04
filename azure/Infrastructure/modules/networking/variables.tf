variable "resource_group" {
  description = "The name of your Azure Resource Group."
  default     = "Terraform-Recipe-Webapp"
}

variable "prefix" {
  description = "This prefix will be included in the name of some resources."
  default     = "recipe-webapp"
}

variable "azurerm_location" {
    description = "Enter azurerm_location. Example (East US) "
    type = string
    default = "East US"
}

variable "virtual_network_name" {
  description = "Enter a valid virtual network name "
  type = string
  default = "vnet"
}

variable "add_space" {
  description = "Enter a valid address space. Example (10.x.x.x/16) "
  type = string
  default = "10.0.0.0/16"
}

variable "subnet1_add_prefix" {
  description = "Enter a valid subnet address prefix. Example (10.x.x.x/24) "
  type = string
  default = "10.0.1.0/24"
}

variable "subnet2_add_prefix" {
  description = "Enter a valid subnet address prefix. Example (10.x.x.x/24) "
  type = string
  default = "10.0.2.0/24"
}

variable "subnet3_add_prefix" {
  description = "Enter a valid subnet address prefix. Example (10.x.x.x/24) "
  type = string
  default = "10.0.3.0/24"
}

variable "vm_size" {
  description = "Specifies the size of the virtual machine."
  default     = "Standard_DS1_v2"
}

variable "image_publisher" {
  description = "Name of the publisher of the image (az vm image list)"
  default     = "Canonical"
}

variable "image_offer" {
  description = "Name of the offer (az vm image list)"
  default     = "UbuntuServer"
}

variable "image_sku" {
  description = "Image SKU to apply (az vm image list)"
  default     = "16.04-LTS"
}

variable "image_version" {
  description = "Version of the image to apply (az vm image list)"
  default     = "latest"
}

variable "admin_username" {
  description = "Administrator user name"
  default     = "adminuser"
}

variable "admin_password" {
  description = "Administrator password"
  default     = "Adminpassword123!"
}