output "aml_workspace_name" {
  value = azurerm_machine_learning_workspace.aml.name
}

output "aml_workspace_id" {
  value = azurerm_machine_learning_workspace.aml.id
}

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "bastion_name" {
  value = azurerm_bastion_host.bastion.name
}

output "jumpbox_vm_name" {
  value = azurerm_windows_virtual_machine.jumpbox.name
}

output "jumpbox_vm_id" {
  description = "Resource ID of the jumpbox VM (used for Bastion tunnel commands)"
  value       = azurerm_windows_virtual_machine.jumpbox.id
}