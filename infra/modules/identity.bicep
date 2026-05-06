// ──────────────────────────────────────────────
// Module: User-Assigned Managed Identity (Workload Identity)
// ──────────────────────────────────────────────

@description('Azure region for the identity')
param location string

@description('Resource naming prefix')
param namePrefix string

@description('Tags to apply to all resources')
param tags object = {}

// ── User-Assigned Managed Identity ──────────

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${namePrefix}-identity'
  location: location
  tags: tags
}

// ── Outputs ─────────────────────────────────

@description('Resource ID of the managed identity')
output identityId string = managedIdentity.id

@description('Principal ID of the managed identity')
output principalId string = managedIdentity.properties.principalId

@description('Client ID of the managed identity')
output clientId string = managedIdentity.properties.clientId

@description('Name of the managed identity')
output identityName string = managedIdentity.name
