variable "azure_subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "azure_location" {
  type        = string
  description = "The Azure location for resources"
  default     = "East US"
}

variable "admin_username" {
  type        = string
  description = "The admin username for the virtual machines"
  default     = "adminuser"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key for the virtual machines"
  type        = string
}
