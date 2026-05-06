// ──────────────────────────────────────────────
// Module: Azure Key Vault
// ──────────────────────────────────────────────

@description('Azure region for Key Vault')
param location string

@description('Resource naming prefix')
param namePrefix string

@description('Tags to apply to all resources')
param tags object = {}

@description('Azure AD tenant ID')
param tenantId string = subscription().tenantId

@description('Enable soft delete')
param enableSoftDelete bool = true

@description('Soft delete retention in days')
@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays int = 90

@description('Enable purge protection (recommended for production)')
param enablePurgeProtection bool = true

@description('Principal ID to grant initial Key Vault access')
param accessPolicyPrincipalId string = ''

// ── Key Vault ───────────────────────────────

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: '${namePrefix}-kv'
  location: location
  tags: tags
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableSoftDelete: enableSoftDelete
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enablePurgeProtection: enablePurgeProtection
    enableRbacAuthorization: true
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
    accessPolicies: empty(accessPolicyPrincipalId) ? [] : [
      {
        tenantId: tenantId
        objectId: accessPolicyPrincipalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
  }
}

// ── Outputs ─────────────────────────────────

@description('Resource ID of the Key Vault')
output keyVaultId string = keyVault.id

@description('Name of the Key Vault')
output keyVaultName string = keyVault.name

@description('URI of the Key Vault')
output keyVaultUri string = keyVault.properties.vaultUri
