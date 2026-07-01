// Variables for resource naming, locations, and tags
// Following Azure Cloud Adoption Framework naming conventions
// https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations

@description('Azure region for resource deployment')
param location string

@description('Environment name (e.g., dev, staging, prod)')
param environment string

@description('Application or project name for resource naming')
param projectName string

@description('Organization abbreviation for resource naming')
param orgPrefix string = ''

// Computed values for consistent naming
var resourceOrgPrefix = length(orgPrefix) > 0 ? '${toLower(orgPrefix)}-' : ''
var resourcePrefix = '${resourceOrgPrefix}${toLower(projectName)}-${toLower(environment)}'

// Storage account naming: lowercase, alphanumeric, 3-24 characters
// Format: {orgprefix}{projectname}{environment}{random}
var storageAccountNameBase = replace('${toLower(orgPrefix)}${toLower(projectName)}${toLower(environment)}${uniqueString(resourceGroup().id)}', '-', '')
var storageAccountName = substring(storageAccountNameBase, 0, min(length(storageAccountNameBase), 24))

// Standard tags for all resources
var commonTags = {
  environment: environment
  projectName: projectName
  deployedBy: 'GitHub Actions'
  deploymentStack: true
}

// Output naming conventions and computed values
output resourcePrefix string = resourcePrefix
output storageAccountName string = storageAccountName
output commonTags object = commonTags
output location string = location
output environment string = environment
