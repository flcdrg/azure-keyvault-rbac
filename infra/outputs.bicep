// Output definitions for deployment information
// These values are displayed after deployment and can be used in subsequent steps

@description('Storage account ID')
param storageAccountId string

@description('Storage account name')
param storageAccountName string

@description('Primary blob endpoint')
param primaryBlobEndpoint string

@description('Resource group name')
param resourceGroupName string

@description('Deployment environment')
param environment string

output storageAccountId string = storageAccountId
output storageAccountName string = storageAccountName
output primaryBlobEndpoint string = primaryBlobEndpoint
output resourceGroupName string = resourceGroupName
output environment string = environment
output deploymentInfo object = {
  environment: environment
  storageAccount: storageAccountName
  resourceGroup: resourceGroupName
}
