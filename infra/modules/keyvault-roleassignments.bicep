@description('Name of the Key Vault to assign RBAC roles to')
param keyVaultName string

@description('Object ID of the deployer principal')
param deployerObjectId string

@description('Object ID of additional principal requiring full access')
param additionalPrincipalObjectId string

var roleDefinitionIds = {
	keyVaultAdministrator: '00482a5a-887f-4fb3-b363-3b7fe8e74483'
	keyVaultCertificatesOfficer: 'a4417e6f-fecd-4de8-b567-7b0420556985'
	keyVaultCryptoOfficer: '14b46e9e-c2b7-41b4-b07b-48a6ebf60603'
	keyVaultSecretsOfficer: 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
  keyVaultSecretsUser: '4633458b-17de-408a-b874-0445c86b69e6'
}

resource keyvault 'Microsoft.KeyVault/vaults@2024-11-01' existing = {
	name: keyVaultName
}

// Deployer access policy equivalents.
resource deployerSecretsOfficerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
	name: guid(keyvault.id, deployerObjectId, roleDefinitionIds.keyVaultSecretsOfficer)
	scope: keyvault
	properties: {
		principalId: deployerObjectId
		roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionIds.keyVaultSecretsOfficer)
		principalType: 'ServicePrincipal'
	}
}

resource deployerCryptoOfficerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
	name: guid(keyvault.id, deployerObjectId, roleDefinitionIds.keyVaultCryptoOfficer)
	scope: keyvault
	properties: {
		principalId: deployerObjectId
		roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionIds.keyVaultCryptoOfficer)
		principalType: 'ServicePrincipal'
	}
}

resource deployerCertificatesOfficerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
	name: guid(keyvault.id, deployerObjectId, roleDefinitionIds.keyVaultCertificatesOfficer)
	scope: keyvault
	properties: {
		principalId: deployerObjectId
		roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionIds.keyVaultCertificatesOfficer)
		principalType: 'ServicePrincipal'
	}
}

resource additionalPrincipalAdministratorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
	name: guid(keyvault.id, additionalPrincipalObjectId, roleDefinitionIds.keyVaultAdministrator)
	scope: keyvault
	properties: {
		principalId: additionalPrincipalObjectId
		roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionIds.keyVaultAdministrator)
		principalType: 'User'
	}
}

// MSA principal access policy equivalents.
resource msaPrincipalSecretsUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyvault.id, '9f9b3ec2-42af-456e-be88-d1b22d86e96b', roleDefinitionIds.keyVaultSecretsUser)
  scope: keyvault
  properties: {
    principalId: '9f9b3ec2-42af-456e-be88-d1b22d86e96b'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionIds.keyVaultSecretsUser)
    principalType: 'User'
  }
}
