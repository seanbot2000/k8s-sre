// ──────────────────────────────────────────────
// Module: Resource Group (subscription-level deployment)
// ──────────────────────────────────────────────
targetScope = 'subscription'

@description('Azure region for the resource group')
param location string

@description('Resource naming prefix')
param namePrefix string

@description('Tags to apply to the resource group')
param tags object = {}

// ── Resource Group ──────────────────────────

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: '${namePrefix}-rg'
  location: location
  tags: tags
}

// ── Outputs ─────────────────────────────────

@description('Resource group name')
output resourceGroupName string = rg.name

@description('Resource group ID')
output resourceGroupId string = rg.id
