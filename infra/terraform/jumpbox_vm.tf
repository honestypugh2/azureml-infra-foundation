resource "azurerm_user_assigned_identity" "jumpbox_identity" {
  name                = "${var.aml_workspace_name}-jumpbox-identity"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

resource "azurerm_network_interface" "jumpbox_nic" {
  name                = "${var.aml_workspace_name}-jumpbox-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet_jumpbox.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "jumpbox" {
  name                = "${var.aml_workspace_name}-jumpbox"
  computer_name       = "aml-jumpbox"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = "Standard_D4s_v3"

  admin_username = "azureuser"
  admin_password = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.jumpbox_nic.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.jumpbox_identity.id]
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

  tags = var.tags
}

# --------------------------------------------------
# Entra ID (AAD) Join – makes the VM a compliant device
# so Conditional Access policies allow browser access
# to Azure ML Studio and other Entra-protected apps.
# --------------------------------------------------
resource "azurerm_virtual_machine_extension" "aad_login" {
  name                       = "AADLoginForWindows"
  virtual_machine_id         = azurerm_windows_virtual_machine.jumpbox.id
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADLoginForWindows"
  type_handler_version       = "2.0"
  auto_upgrade_minor_version = true
  tags                       = var.tags
}

# Allow your Entra ID user to RDP into the Entra-joined VM
resource "azurerm_role_assignment" "jumpbox_vm_admin_login" {
  scope                = azurerm_windows_virtual_machine.jumpbox.id
  role_definition_name = "Virtual Machine Administrator Login"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Grant the jumpbox managed identity Contributor on the resource group
resource "azurerm_role_assignment" "jumpbox_contributor" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.jumpbox_identity.principal_id
}

# Grant the jumpbox managed identity AzureML Data Scientist role on the workspace
resource "azurerm_role_assignment" "jumpbox_aml_ds" {
  scope                = azurerm_machine_learning_workspace.aml.id
  role_definition_name = "AzureML Data Scientist"
  principal_id         = azurerm_user_assigned_identity.jumpbox_identity.principal_id
}