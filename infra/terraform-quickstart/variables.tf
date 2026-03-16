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

variable "compute_instance_name" {
  description = "Name for the Azure ML compute instance"
  type        = string
  default     = "cpu-instance"
}

variable "compute_cluster_name" {
  description = "Name for the Azure ML compute cluster"
  type        = string
  default     = "cpu-cluster"
}

variable "compute_vm_size" {
  description = "VM size for compute instance and cluster"
  type        = string
  default     = "Standard_DS3_v2"
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}
