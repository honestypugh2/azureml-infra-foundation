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
# Log Analytics + Application Insights
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
# Storage Account (AML default datastore)
# --------------------------------------------------
resource "azurerm_storage_account" "sa" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  min_tls_version                 = "TLS1_2"
  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = false

  tags = var.tags
}

# --------------------------------------------------
# Azure Container Registry
# --------------------------------------------------
resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = false

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
  purge_protection_enabled   = false
  soft_delete_retention_days = 7

  tags = var.tags
}

# --------------------------------------------------
# Azure Machine Learning Workspace (Public Access)
# --------------------------------------------------
resource "azurerm_machine_learning_workspace" "aml" {
  name                = var.aml_workspace_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  application_insights_id = azurerm_application_insights.appi.id
  key_vault_id            = azurerm_key_vault.kv.id
  storage_account_id      = azurerm_storage_account.sa.id
  container_registry_id   = azurerm_container_registry.acr.id

  public_network_access_enabled = true

  identity {
    type = "SystemAssigned"
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
# RBAC: Storage Blob Data Contributor for current user
# --------------------------------------------------
resource "azurerm_role_assignment" "user_blob_contributor" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# --------------------------------------------------
# RBAC: Storage File Data Privileged Contributor for current user
# --------------------------------------------------
resource "azurerm_role_assignment" "user_file_contributor" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage File Data Privileged Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# --------------------------------------------------
# RBAC: Storage Blob Data Contributor for compute cluster
# --------------------------------------------------
resource "azurerm_role_assignment" "cluster_blob_contributor" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_machine_learning_compute_cluster.cc.identity[0].principal_id
}

# --------------------------------------------------
# RBAC: Storage File Data Privileged Contributor for compute cluster
# --------------------------------------------------
resource "azurerm_role_assignment" "cluster_file_contributor" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage File Data Privileged Contributor"
  principal_id         = azurerm_machine_learning_compute_cluster.cc.identity[0].principal_id
}

# --------------------------------------------------
# Switch default datastore to identity-based auth
# --------------------------------------------------
resource "null_resource" "datastore_identity_auth" {
  depends_on = [
    azurerm_machine_learning_workspace.aml,
    azurerm_role_assignment.user_blob_contributor,
    azurerm_role_assignment.user_file_contributor,
  ]

  provisioner "local-exec" {
    command = <<-EOT
      CONTAINER=$(az ml datastore show \
        --name workspaceblobstore \
        --resource-group ${azurerm_resource_group.rg.name} \
        --workspace-name ${azurerm_machine_learning_workspace.aml.name} \
        --query container_name -o tsv)

      TMPFILE=$(mktemp /tmp/datastore-XXXXXX.yaml)
      cat > "$TMPFILE" <<YAML
      \$schema: https://azuremlschemas.azureedge.net/latest/azureBlob.schema.json
      name: workspaceblobstore
      account_name: ${azurerm_storage_account.sa.name}
      container_name: $CONTAINER
      YAML

      az ml datastore create \
        --file "$TMPFILE" \
        --resource-group ${azurerm_resource_group.rg.name} \
        --workspace-name ${azurerm_machine_learning_workspace.aml.name}

      rm -f "$TMPFILE"
    EOT
  }
}

# --------------------------------------------------
# Azure ML Compute Instance (for notebooks / dev)
# --------------------------------------------------
resource "azurerm_machine_learning_compute_instance" "ci" {
  name                          = "${var.compute_instance_name}-${substr(md5(azurerm_machine_learning_workspace.aml.id), 0, 6)}"
  machine_learning_workspace_id = azurerm_machine_learning_workspace.aml.id
  virtual_machine_size          = var.compute_vm_size

  authorization_type = "personal"

  assign_to_user {
    object_id = data.azurerm_client_config.current.object_id
    tenant_id = data.azurerm_client_config.current.tenant_id
  }

  tags = var.tags
}

# --------------------------------------------------
# Azure ML Compute Cluster (for training jobs)
# --------------------------------------------------
resource "azurerm_machine_learning_compute_cluster" "cc" {
  name                          = var.compute_cluster_name
  machine_learning_workspace_id = azurerm_machine_learning_workspace.aml.id
  vm_size                       = var.compute_vm_size
  vm_priority                   = "Dedicated"
  location                      = var.location

  scale_settings {
    min_node_count                       = 0
    max_node_count                       = 2
    scale_down_nodes_after_idle_duration = "PT120S"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}
