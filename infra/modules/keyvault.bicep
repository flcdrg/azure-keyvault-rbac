@description('Azure region for the storage account')
param location string

@description('Resource tags')
param tags object = {}

resource keyvault 'Microsoft.KeyVault/vaults@2024-11-01' = {
  name: 'kv-accesspolicy'
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    accessPolicies: []
    enableSoftDelete: false
  }
  tags: tags
}
