variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
}

variable "location" {
  type    = string
  default = "westeurope"
}

variable "cp_vm_size" {
  type    = string
  default = "Standard_B2s"
}

variable "worker_vm_size" {
  type    = string
  default = "Standard_B1ms"
}

variable "admin_username" {
  type    = string
  default = "azureuser"
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/lh_assignment.pub"
}

variable "allowed_ip_cidr" {
  type        = string
  description = "Your public IP in CIDR form, e.g. 1.2.3.4/32"
}

variable "image_sku" {
  type    = string
  default = "server"
}

variable "worker_count" {
  type    = number
  default = 2
}
