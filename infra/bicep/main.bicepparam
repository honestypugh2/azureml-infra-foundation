using './main.bicep'

param location = 'eastus'
param amlWorkspaceName = 'amlw-us11-dev'
param amlWorkspaceSku = 'Basic'

param namePrefix = 'amlwus11dev'
param storageAccountName = 'stamlwus11dev01'
param containerRegistryName = 'cramlwus11dev01'
param keyVaultName = 'kv-amlw-us11-dev'

param deployContainerRegistry = true
param publicNetworkAccess = 'Disabled'

param managedNetworkSettings = {
  isolationMode: 'AllowInternetOutbound'
}

param systemDatastoresAuthMode = 'Identity'

param tags = {
  environment: 'dev'
  workload: 'aml'
  module: 'us-1-1'
}
