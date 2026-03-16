data "azurerm_client_config" "current" {}

# --------------------------------------------------
# Resource Group
# --------------------------------------------------
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# --------------------------------------------------
# Jumpbox Virtual Network (workspace inbound access)
# --------------------------------------------------
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.aml_workspace_name}-vnet"
  address_space       = ["10.30.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

resource "azurerm_subnet" "snet_jumpbox" {
  name                 = "snet-jumpbox"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.30.1.0/24"]
}

# --------------------------------------------------
# NAT Gateway – provides outbound internet for the
# jumpbox (Edge, az login, Windows Update, etc.)
# --------------------------------------------------
resource "azurerm_public_ip" "nat_pip" {
  name                = "${var.aml_workspace_name}-nat-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway" "jumpbox_nat" {
  name                    = "${var.aml_workspace_name}-nat-gw"
  location                = var.location
  resource_group_name     = azurerm_resource_group.rg.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  tags                    = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "nat_pip_assoc" {
  nat_gateway_id       = azurerm_nat_gateway.jumpbox_nat.id
  public_ip_address_id = azurerm_public_ip.nat_pip.id
}

resource "azurerm_subnet_nat_gateway_association" "jumpbox_nat_assoc" {
  subnet_id      = azurerm_subnet.snet_jumpbox.id
  nat_gateway_id = azurerm_nat_gateway.jumpbox_nat.id
}

# --------------------------------------------------
# Log Analytics + App Insights
# --------------------------------------------------
resource "azurerm_log_analytics_workspace" "law" {
  name                = "${var.aml_workspace_name}-law"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_application_insights" "appi" {
  name                = "${var.aml_workspace_name}-appi"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.law.id
  tags                = var.tags
}

# --------------------------------------------------
# Storage Account (AML Default Datastore)
# --------------------------------------------------
resource "azurerm_storage_account" "sa" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }

  tags = var.tags
}

# --------------------------------------------------
# Azure Container Registry
# --------------------------------------------------
resource "azurerm_container_registry" "acr" {
  name                          = var.acr_name
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = var.location
  sku                           = "Premium"
  admin_enabled                 = false
  public_network_access_enabled = false

  tags = var.tags
}

# --------------------------------------------------
# Key Vault
# --------------------------------------------------
resource "azurerm_key_vault" "kv" {
  name                       = var.key_vault_name
  location                   = var.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  purge_protection_enabled   = true
  soft_delete_retention_days = 7

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  tags = var.tags
}

# --------------------------------------------------
# Azure Machine Learning Workspace (Managed VNet)
# --------------------------------------------------
resource "azurerm_machine_learning_workspace" "aml" {
  name                = var.aml_workspace_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  application_insights_id = azurerm_application_insights.appi.id
  key_vault_id            = azurerm_key_vault.kv.id
  storage_account_id      = azurerm_storage_account.sa.id
  container_registry_id   = azurerm_container_registry.acr.id

  public_network_access_enabled = false

  identity {
    type = "SystemAssigned"
  }

  managed_network {
    isolation_mode = var.aml_isolation_mode
    # Valid values commonly used: "AllowInternetOutbound" or "AllowOnlyApprovedOutbound"
  }


  tags = merge(
    var.tags,
    {
      workload = "lstm-timeseries"
      repo     = "aml-v2-lstm-ts-forecasting-demo"
    }
  )
}

# --------------------------------------------------
# Workspace identity RBAC on backing services
# (required per MS docs for managed VNet isolation)
# --------------------------------------------------

# Storage: workspace needs blob + file data access
resource "azurerm_role_assignment" "aml_sa_blob" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_machine_learning_workspace.aml.identity[0].principal_id
}

resource "azurerm_role_assignment" "aml_sa_file" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage File Data Privileged Contributor"
  principal_id         = azurerm_machine_learning_workspace.aml.identity[0].principal_id
}

# ACR: workspace needs push/pull for training environment images
resource "azurerm_role_assignment" "aml_acr_push" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPush"
  principal_id         = azurerm_machine_learning_workspace.aml.identity[0].principal_id
}

# Key Vault: workspace needs secrets/keys access
resource "azurerm_role_assignment" "aml_kv_admin" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = azurerm_machine_learning_workspace.aml.identity[0].principal_id
}

# Deployer: privateEndpointConnections read/write on workspace
# (required for managed VNet provisioning)
resource "azurerm_role_assignment" "deployer_aml_contributor" {
  scope                = azurerm_machine_learning_workspace.aml.id
  role_definition_name = "Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# --------------------------------------------------
# AML CPU Compute Cluster
# --------------------------------------------------
resource "azurerm_machine_learning_compute_cluster" "cpu" {
  name                          = "cpu-cluster"
  location                      = var.location
  machine_learning_workspace_id = azurerm_machine_learning_workspace.aml.id
  vm_size                       = "Standard_DS3_v2"
  vm_priority                   = "Dedicated"

  scale_settings {
    min_node_count                       = 0
    max_node_count                       = 4
    scale_down_nodes_after_idle_duration = "PT120S"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# --------------------------------------------------
# Private DNS Zones (workspace inbound via jumpbox)
# --------------------------------------------------
resource "azurerm_private_dns_zone" "aml_api" {
  name                = "privatelink.api.azureml.ms"
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "aml_notebooks" {
  name                = "privatelink.notebooks.azure.net"
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "aml_api_link" {
  name                  = "aml-api-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.aml_api.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "aml_notebooks_link" {
  name                  = "aml-notebooks-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.aml_notebooks.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

# --------------------------------------------------
# Workspace Private Endpoint (inbound from jumpbox)
# --------------------------------------------------
resource "azurerm_private_endpoint" "aml_pe" {
  name                = "${var.aml_workspace_name}-pe"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.snet_jumpbox.id

  private_service_connection {
    name                           = "${var.aml_workspace_name}-psc"
    private_connection_resource_id = azurerm_machine_learning_workspace.aml.id
    subresource_names              = ["amlworkspace"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name = "aml-dns-group"
    private_dns_zone_ids = [
      azurerm_private_dns_zone.aml_api.id,
      azurerm_private_dns_zone.aml_notebooks.id,
    ]
  }

  tags = var.tags
}

# --------------------------------------------------
# Private DNS Zones for backing services
# --------------------------------------------------
resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "file" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "vault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "acr" {
  name                = "privatelink.azurecr.io"
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

# --------------------------------------------------
# VNet links for backing-service DNS zones
# --------------------------------------------------
resource "azurerm_private_dns_zone_virtual_network_link" "blob_link" {
  name                  = "blob-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "file_link" {
  name                  = "file-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.file.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "vault_link" {
  name                  = "vault-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.vault.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr_link" {
  name                  = "acr-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.acr.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

# --------------------------------------------------
# Storage Account Private Endpoint
# --------------------------------------------------
resource "azurerm_private_endpoint" "sa_blob_pe" {
  name                = "${var.storage_account_name}-blob-pe"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.snet_jumpbox.id

  private_service_connection {
    name                           = "${var.storage_account_name}-blob-psc"
    private_connection_resource_id = azurerm_storage_account.sa.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "blob-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }

  tags = var.tags
}

# --------------------------------------------------
# Storage Account File Share Private Endpoint
# --------------------------------------------------
resource "azurerm_private_endpoint" "sa_file_pe" {
  name                = "${var.storage_account_name}-file-pe"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.snet_jumpbox.id

  private_service_connection {
    name                           = "${var.storage_account_name}-file-psc"
    private_connection_resource_id = azurerm_storage_account.sa.id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "file-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.file.id]
  }

  tags = var.tags
}

# --------------------------------------------------
# Key Vault Private Endpoint
# --------------------------------------------------
resource "azurerm_private_endpoint" "kv_pe" {
  name                = "${var.key_vault_name}-pe"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.snet_jumpbox.id

  private_service_connection {
    name                           = "${var.key_vault_name}-psc"
    private_connection_resource_id = azurerm_key_vault.kv.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "vault-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.vault.id]
  }

  tags = var.tags
}

# --------------------------------------------------
# Container Registry Private Endpoint
# --------------------------------------------------
resource "azurerm_private_endpoint" "acr_pe" {
  name                = "${var.acr_name}-pe"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.snet_jumpbox.id

  private_service_connection {
    name                           = "${var.acr_name}-psc"
    private_connection_resource_id = azurerm_container_registry.acr.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "acr-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.acr.id]
  }

  tags = var.tags
}