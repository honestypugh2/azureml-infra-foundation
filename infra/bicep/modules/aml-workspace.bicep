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
param associatedContainerRegistryResourceId string = ''

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

var formattedUserAssignedIdentities = reduce(
  map((managedIdentities.?userAssignedResourceIds ?? []), (id) => { '${id}': {} }),
  {},
  (cur, next) => union(cur, next)
)

var identity = {
  type: (managedIdentities.?systemAssigned ?? false)
    ? (!empty(formattedUserAssignedIdentities) ? 'SystemAssigned,UserAssigned' : 'SystemAssigned')
    : (!empty(formattedUserAssignedIdentities) ? 'UserAssigned' : 'None')
  userAssignedIdentities: !empty(formattedUserAssignedIdentities) ? formattedUserAssignedIdentities : null
}

// Create the AML workspace and attach required backing resources by resource ID.
resource workspace 'Microsoft.MachineLearningServices/workspaces@2024-10-01-preview' = {
  name: name
  location: location
  kind: kind
  tags: tags
  sku: {
    name: sku
    tier: sku
  }
  identity: identity
  properties: {
    friendlyName: name
    storageAccount: associatedStorageAccountResourceId
    keyVault: associatedKeyVaultResourceId
    applicationInsights: associatedApplicationInsightsResourceId
    containerRegistry: empty(associatedContainerRegistryResourceId) ? null : associatedContainerRegistryResourceId
    publicNetworkAccess: publicNetworkAccess
    managedNetwork: managedNetworkSettings
    systemDatastoresAuthMode: systemDatastoresAuthMode
  }
}

output id string = workspace.id
output name string = workspace.name
output principalId string = workspace.identity.principalId
