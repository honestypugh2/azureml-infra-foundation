// Composes the US-1.1 AML baseline by deploying backing services and then wiring an AML workspace to them.
targetScope = 'resourceGroup'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Name of the AML workspace.')
param amlWorkspaceName string

@description('AML workspace SKU.')
@allowed([
  'Free'
  'Basic'
  'Standard'
  'Premium'
])
param amlWorkspaceSku string = 'Basic'

@description('Base prefix used to construct resource names.')
param namePrefix string

@description('Storage account name (3-24 lower-case alphanumeric).')
param storageAccountName string

@description('Container registry name (5-50 alphanumeric).')
param containerRegistryName string

@description('Key Vault name (3-24 alphanumeric and dash).')
param keyVaultName string

@description('Optional name override for Log Analytics.')
param logAnalyticsWorkspaceName string = '${namePrefix}-law'

@description('Optional name override for Application Insights.')
param applicationInsightsName string = '${namePrefix}-appi'

@description('Deploy ACR as a dependency for AML workspace image build.')
param deployContainerRegistry bool = true

@description('Whether public network access is enabled on AML workspace.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Disabled'

@description('Managed network settings object for AML workspace.')
param managedNetworkSettings object = {
  isolationMode: 'AllowInternetOutbound'
}

@description('Authentication mode for system datastores.')
@allowed([
  'AccessKey'
  'Identity'
  'UserDelegationSAS'
])
param systemDatastoresAuthMode string = 'Identity'

@description('Tags applied to all resources.')
param tags object = {}

// Deploy shared AML dependencies (storage, key vault, monitoring, optional ACR).
module backingServices 'modules/backing-services.bicep' = {
  name: 'backing-services'
  params: {
    location: location
    namePrefix: namePrefix
    storageAccountName: storageAccountName
    containerRegistryName: containerRegistryName
    keyVaultName: keyVaultName
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    applicationInsightsName: applicationInsightsName
    deployContainerRegistry: deployContainerRegistry
    tags: tags
  }
}

// Deploy the AML workspace using IDs produced by the backing-services module.
module amlWorkspace 'modules/aml-workspace.bicep' = {
  name: 'aml-workspace'
  params: {
    name: amlWorkspaceName
    location: location
    sku: amlWorkspaceSku
    associatedStorageAccountResourceId: backingServices.outputs.storageAccountId
    associatedKeyVaultResourceId: backingServices.outputs.keyVaultId
    associatedApplicationInsightsResourceId: backingServices.outputs.applicationInsightsId
    associatedContainerRegistryResourceId: deployContainerRegistry ? backingServices.outputs.containerRegistryId : ''
    publicNetworkAccess: publicNetworkAccess
    managedNetworkSettings: managedNetworkSettings
    systemDatastoresAuthMode: systemDatastoresAuthMode
    tags: tags
  }
}

output workspaceId string = amlWorkspace.outputs.id
output workspaceName string = amlWorkspace.outputs.name
output workspacePrincipalId string = amlWorkspace.outputs.principalId
output storageAccountId string = backingServices.outputs.storageAccountId
output keyVaultId string = backingServices.outputs.keyVaultId
output applicationInsightsId string = backingServices.outputs.applicationInsightsId
output containerRegistryId string = backingServices.outputs.containerRegistryId
