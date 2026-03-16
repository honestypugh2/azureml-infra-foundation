variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "aml_workspace_name" {
  description = "Azure ML workspace name"
  type        = string
}

variable "aml_isolation_mode" {
  type        = string
  description = "Managed network isolation mode for AML workspace"
  default     = "AllowInternetOutbound"
}


variable "storage_account_name" {
  description = "Globally unique storage account name"
  type        = string
}

variable "acr_name" {
  description = "Globally unique Azure Container Registry name"
  type        = string
}

variable "key_vault_name" {
  description = "Globally unique Key Vault name"
  type        = string
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}

variable "admin_password" {
  description = "Password for the Windows jumpbox VM admin user (azureuser). Must meet Azure complexity requirements: 12+ chars, uppercase, lowercase, digit, special character."
  type        = string
  sensitive   = true
}