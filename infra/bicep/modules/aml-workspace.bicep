// Deploys a single AML workspace with AVM-aligned inputs for identity, network posture, and linked dependencies.
targetScope = 'resourceGroup'

@description('Name of the AML workspace.')
param name string

@description('Location for the workspace.')
param location string = resourceGroup().location

@description('AML workspace SKU.')
@allowed([
  'Free'
  'Basic'
  'Standard'
  'Premium'
])
param sku string = 'Basic'

@description('Workspace kind.')
@allowed([
  'Default'
  'Project'
  'Hub'
  'FeatureStore'
])
param kind string = 'Default'

@description('Resource ID for the associated storage account.')
param associatedStorageAccountResourceId string

@description('Resource ID for the associated key vault.')
param associatedKeyVaultResourceId string

@description('Resource ID for the associated application insights component.')
param associatedApplicationInsightsResourceId string

@description('Optional resource ID for the associated container registry.')
param associatedContainerRegistryResourceId string?

@description('Whether public network access is enabled.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Disabled'

@description('Workspace managed identities, AVM-aligned shape.')
param managedIdentities object = {
  systemAssigned: true
}

@description('Managed network settings for AML.')
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

@description('Tags applied to the workspace.')
param tags object = {}

// Create the AML workspace and attach required backing resources by resource ID.
module workspace 'br/public:avm/res/machine-learning-services/workspace:0.13.2' = {
  name: 'workspace'
  params: {
    name: name
    location: location
    sku: sku
    kind: kind
    associatedStorageAccountResourceId: associatedStorageAccountResourceId
    associatedKeyVaultResourceId: associatedKeyVaultResourceId
    associatedApplicationInsightsResourceId: associatedApplicationInsightsResourceId
    associatedContainerRegistryResourceId: associatedContainerRegistryResourceId
    managedIdentities: managedIdentities
    publicNetworkAccess: publicNetworkAccess
    managedNetworkSettings: managedNetworkSettings
    systemDatastoresAuthMode: systemDatastoresAuthMode
    tags: tags
  }
}

output id string = workspace.outputs.resourceId
output name string = workspace.outputs.name
output principalId string? = workspace.outputs.?systemAssignedMIPrincipalId
