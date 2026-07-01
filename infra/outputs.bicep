// Output definitions for deployment information
// These values are displayed after deployment and can be used in subsequent steps



@description('Resource group name')
param resourceGroupName string

@description('Deployment environment')
param environment string

output resourceGroupName string = resourceGroupName
output environment string = environment
output deploymentInfo object = {
  environment: environment
  resourceGroup: resourceGroupName
}
