
variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "location" {
  description = "Azure deployment region"
  type        = string
  default     = "centralindia"
}

variable "vm_size" {
  description = "VM Scale Set instance size"
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Linux administrator username"
  type        = string
  default     = "azureuser"
}

variable "admin_ssh_public_key" {
  description = "SSH public key content"
  type        = string
}

variable "admin_ssh_cidr" {
  description = "Student public IP CIDR for SSH access"
  type        = string
}
