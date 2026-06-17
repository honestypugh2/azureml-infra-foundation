// Deploys AML backing services (monitoring, storage, secrets, and optional registry) with secure defaults.
targetScope = 'resourceGroup'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Name prefix used for AML-aligned backing resources.')
param namePrefix string

@description('Globally unique name for the storage account (3-24 lower-case alphanumeric).')
param storageAccountName string

@description('Globally unique name for Azure Container Registry (5-50 alphanumeric).')
param containerRegistryName string

@description('Name for Azure Key Vault.')
param keyVaultName string

@description('Name for Log Analytics workspace.')
param logAnalyticsWorkspaceName string = '${namePrefix}-law'

@description('Name for Application Insights instance.')
param applicationInsightsName string = '${namePrefix}-appi'

@description('Whether to deploy ACR for AML image build and environment assets.')
param deployContainerRegistry bool = true

@description('Tags applied to all resources.')
param tags object = {}

// Create the Log Analytics workspace used as the telemetry sink.
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Create Application Insights connected to the Log Analytics workspace.
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

// Create the default AML storage account with public access and shared keys disabled.
resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    defaultToOAuthAuthentication: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
  }
}

// Create Key Vault for AML secrets/keys with private-only network access.
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enablePurgeProtection: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
  }
}

// Optionally create ACR for AML environment images and build artifacts.
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = if (deployContainerRegistry) {
  name: containerRegistryName
  location: location
  tags: tags
  sku: {
    name: 'Premium'
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Disabled'
  }
}

output logAnalyticsWorkspaceId string = logAnalytics.id
output applicationInsightsId string = applicationInsights.id
output storageAccountId string = storage.id
output keyVaultId string = keyVault.id
output containerRegistryId string = deployContainerRegistry ? containerRegistry.id : ''
