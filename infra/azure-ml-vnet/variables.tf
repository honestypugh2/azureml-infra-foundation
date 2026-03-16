variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group to create"
  type        = string
  default     = "aml-managed-vnet-rg"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
  default     = "aml-managed-vnet"
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.1.0.0/16"]
}

variable "subnet_name" {
  description = "Name of the subnet delegated to Azure ML"
  type        = string
  default     = "aml-managed-subnet"
}

variable "subnet_prefix" {
  description = "Address prefix for the Azure ML subnet"
  type        = string
  default     = "10.1.0.0/24"
}

variable "nsg_name" {
  description = "Name of the network security group"
  type        = string
  default     = "aml-managed-nsg"
}

variable "route_table_name" {
  description = "Name of the route table"
  type        = string
  default     = "aml-managed-rt"
}

variable "user_assigned_identity_name" {
  description = "Name of the user-assigned managed identity for Azure ML"
  type        = string
  default     = "aml-managed-uai"
}
