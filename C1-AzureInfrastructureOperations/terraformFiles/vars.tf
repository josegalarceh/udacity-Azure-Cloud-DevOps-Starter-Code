variable "project" {
  description = "The name of the proyect which should be used for all resources in this example"
  default = "udacity"
}

variable "location" {
  description = "The Azure Region in which all resources in this example should be created."
  default = "East US 2"
}

variable "role" {
  description = "role tag name"
  default = "devops"
}

variable "number-of-vms" {
  type        = number
  description = "Virtual machine counts"
  default     = 1
}

variable "linux-vm-image" {
  type        = map(string)
  description = "Virtual machine source image information"
  default = {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
  }
}