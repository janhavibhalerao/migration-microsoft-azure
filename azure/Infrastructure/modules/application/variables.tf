variable "rg_name" {
    description = "Enter resource group"
    type = string
}

variable "rg_id" {}

variable "subnet_id1" {}

variable "rg_location" {
    description = "Enter resource group location. Example (East US)"
    type = string
}

variable "prefix" {
  description = "This prefix will be included in the name of some resources."
  default     = "recipe-webapp"
}

variable "admin_username" {
  description = "Administrator user name"
  default     = "adminuser"
}

variable "admin_password" {
  description = "Administrator password"
  default     = "Adminpassword123!"
}