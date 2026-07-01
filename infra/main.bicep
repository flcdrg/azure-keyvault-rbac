// Main Bicep template for Azure Deployment Stacks
// Deploys infrastructure resources using modular components

// Parameters
@description('Azure region for resource deployment')
param location string = resourceGroup().location

@description('Environment name (e.g., dev, staging, prod)')
param environment string

@description('Project name for resource naming')
param projectName string = 'stack'

@description('Organization prefix for resource naming')
param orgPrefix string = ''

// Load variables module
module variables 'variables.bicep' = {
  name: 'variablesModule'
  params: {
    location: location
    environment: environment
    projectName: projectName
    orgPrefix: orgPrefix
  }
}

module keyvaultModule 'modules/keyvault.bicep' = {
  name: 'keyvaultModule'
  params: {
    location: location
    tags: variables.outputs.commonTags
  }
}

// Load outputs module
module outputsModule 'outputs.bicep' = {
  name: 'outputsModule'
  params: {
    resourceGroupName: resourceGroup().name
    environment: environment
  }
}

// Root outputs
output deploymentInfo object = outputsModule.outputs.deploymentInfo
output environment string = outputsModule.outputs.environment
