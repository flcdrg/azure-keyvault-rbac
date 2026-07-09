@description('Azure region for the storage account')
param location string

@description('Resource tags')
param tags object = {}

resource keyvault 'Microsoft.KeyVault/vaults@2024-11-01' = {
  name: 'kv-accpol-g79v-aue'
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId

    // Enable RBAC authorization for the Key Vault
    enableRbacAuthorization: false

    accessPolicies: [
      {
        objectId: deployer().objectId
        permissions: {
          certificates: [
            'ManageContacts'
          ]
          keys: [
            'Create'
          ]
          secrets: [
            'Get'
            'Set'
          ]
          storage: []
        }
        tenantId: tenant().tenantId
      }
      {
        objectId: '39655ba2-10df-4265-80a7-8b32f7c50e7b'
        permissions: {
          certificates: [
            'all'
          ]
          keys: [
            'all'
          ]
          secrets: [
            'all'
          ]
          storage: [
            'all'
          ]
        }
        tenantId: tenant().tenantId
      }
      // MSA principal access policy equivalent.
      {objectId: '9f9b3ec2-42af-456e-be88-d1b22d86e96b'
        permissions: {
          certificates: []
          keys: []
          secrets: [
            'Get'
          ]
          storage: []
        }
        tenantId: tenant().tenantId
      }
    ]
    enableSoftDelete: false
  }
  tags: tags
}

resource bicepSecret 'Microsoft.KeyVault/vaults/secrets@2024-11-01' = {
  parent: keyvault
  name: 'shoosh'
  properties: {
    value: 'bicep'
  }
}

module keyvaultRoleAssignments 'keyvault-roleassignments.bicep' = {
  params: {
    keyVaultName: keyvault.name
    deployerObjectId: deployer().objectId
    additionalPrincipalObjectId: '39655ba2-10df-4265-80a7-8b32f7c50e7b'
  }
}
