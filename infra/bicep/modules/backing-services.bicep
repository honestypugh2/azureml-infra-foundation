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
module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.15.1' = {
  name: 'law'
  params: {
    name: logAnalyticsWorkspaceName
    location: location
    skuName: 'PerGB2018'
    dataRetention: 30
    tags: tags
  }
}

// Create Application Insights connected to the Log Analytics workspace.
module applicationInsights 'br/public:avm/res/insights/component:0.7.2' = {
  name: 'appi'
  params: {
    name: applicationInsightsName
    location: location
    applicationType: 'web'
    workspaceResourceId: logAnalytics.outputs.resourceId
    tags: tags
  }
}

// Create the default AML storage account with public access and shared keys disabled.
module storage 'br/public:avm/res/storage/storage-account:0.32.1' = {
  name: 'storage'
  params: {
    name: storageAccountName
    location: location
    kind: 'StorageV2'
    skuName: 'Standard_LRS'
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    defaultToOAuthAuthentication: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    tags: tags
  }
}

// Create Key Vault for AML secrets/keys with private-only network access.
module keyVault 'br/public:avm/res/key-vault/vault:0.13.3' = {
  name: 'key-vault'
  params: {
    name: keyVaultName
    location: location
    sku: 'standard'
    enableVaultForDeployment: false
    enableVaultForDiskEncryption: false
    enableVaultForTemplateDeployment: false
    enablePurgeProtection: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    tags: tags
  }
}

// Optionally create ACR for AML environment images and build artifacts.
module containerRegistry 'br/public:avm/res/container-registry/registry:0.12.1' = if (deployContainerRegistry) {
  name: 'acr'
  params: {
    name: containerRegistryName
    location: location
    acrSku: 'Premium'
    acrAdminUserEnabled: false
    publicNetworkAccess: 'Disabled'
    tags: tags
  }
}

output logAnalyticsWorkspaceId string = logAnalytics.outputs.resourceId
output applicationInsightsId string = applicationInsights.outputs.resourceId
output storageAccountId string = storage.outputs.resourceId
output keyVaultId string = keyVault.outputs.resourceId
output containerRegistryId string = deployContainerRegistry ? (containerRegistry.?outputs.resourceId ?? '') : ''
