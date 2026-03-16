output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "aml_workspace_name" {
  value = azurerm_machine_learning_workspace.aml.name
}

output "aml_workspace_id" {
  value = azurerm_machine_learning_workspace.aml.id
}

output "aml_studio_url" {
  description = "Direct link to Azure ML Studio for this workspace"
  value       = "https://ml.azure.com/home?wsid=${azurerm_machine_learning_workspace.aml.id}"
}

output "storage_account_name" {
  value = azurerm_storage_account.sa.name
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "compute_instance_name" {
  description = "Actual compute instance name (includes unique suffix)"
  value       = azurerm_machine_learning_compute_instance.ci.name
}

output "compute_cluster_name" {
  value = azurerm_machine_learning_compute_cluster.cc.name
}
