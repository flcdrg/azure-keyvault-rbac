// Azure Storage Account Module
// Deploys a storage account with configurable SKU and access tier

@description('Storage account name (must be globally unique, lowercase alphanumeric)')
param storageAccountName string

@description('Azure region for the storage account')
param location string

@description('Storage account SKU (Standard_LRS, Standard_GRS, Standard_RAGRS, Premium_LRS)')
param skuName string = 'Standard_LRS'

@description('Access tier (Hot or Cool)')
param accessTier string = 'Hot'

@description('Resource tags')
param tags object = {}

// Storage account resource
resource storageAccount 'Microsoft.Storage/storageAccounts@2025-08-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: skuName
  }
  properties: {
    accessTier: accessTier
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
      }
      keySource: 'Microsoft.Storage'
    }
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
  }
  tags: tags
}

// Blob services
resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2025-08-01' = {
  parent: storageAccount
  name: 'default'
}

output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output primaryBlobEndpoint string = storageAccount.properties.primaryEndpoints.blob
output storageAccountResourceGroup string = resourceGroup().name
