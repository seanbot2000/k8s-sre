// ──────────────────────────────────────────────
// Azure SRE Agent — Standalone Service
// Deploys as Microsoft.App/agents (2025-05-01-preview)
// Monitors AKS cluster externally via RBAC-granted access
// ──────────────────────────────────────────────

param location string
param namePrefix string
param tags object

@description('Resource ID of the AKS cluster to monitor')
param aksClusterId string

@description('Resource ID of the Log Analytics workspace')
param logAnalyticsWorkspaceId string

@description('Monthly agent unit limit (default 10000)')
param monthlyAgentUnitLimit int = 10000

@description('Deploy the SRE Agent (set false if preview not available)')
param deploySreAgent bool = true

// ── SRE Agent Resource ───────────────────────

resource sreAgent 'Microsoft.App/agents@2025-05-01-preview' = if (deploySreAgent) {
  name: '${namePrefix}-sre-agent'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    monthlyAgentUnitLimit: monthlyAgentUnitLimit
  }
}

// ── RBAC: Reader on resource group (inherited from parent deployment scope) ──

@description('Built-in Reader role definition ID')
var readerRoleId = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'

@description('Built-in Log Analytics Reader role definition ID')
var logAnalyticsReaderRoleId = '73c42c96-874c-492b-b04d-ab87d138a893'

@description('Built-in AKS Cluster User role definition ID')
var aksClusterUserRoleId = '4abbcc35-e782-43d8-92c5-2d3f1bd2253f'

// Reader on resource group
resource readerRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deploySreAgent) {
  name: guid(resourceGroup().id, sreAgent.id, readerRoleId)
  properties: {
    principalId: deploySreAgent ? sreAgent.identity.principalId : ''
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', readerRoleId)
  }
}

// AKS Cluster User on the AKS resource
resource aksClusterUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deploySreAgent) {
  name: guid(aksClusterId, sreAgent.id, aksClusterUserRoleId)
  scope: aksCluster
  properties: {
    principalId: deploySreAgent ? sreAgent.identity.principalId : ''
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', aksClusterUserRoleId)
  }
}

// Log Analytics Reader on workspace
resource logReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deploySreAgent) {
  name: guid(logAnalyticsWorkspaceId, sreAgent.id, logAnalyticsReaderRoleId)
  scope: logAnalyticsWorkspace
  properties: {
    principalId: deploySreAgent ? sreAgent.identity.principalId : ''
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', logAnalyticsReaderRoleId)
  }
}

// ── Existing resource references for RBAC scoping ──

resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-09-01' existing = {
  name: last(split(aksClusterId, '/'))
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: last(split(logAnalyticsWorkspaceId, '/'))
}

// ── Outputs ─────────────────────────────────

@description('SRE Agent resource ID')
output sreAgentId string = deploySreAgent ? sreAgent.id : ''

@description('SRE Agent name')
output sreAgentName string = deploySreAgent ? sreAgent.name : ''

@description('SRE Agent managed identity principal ID')
output sreAgentPrincipalId string = deploySreAgent ? sreAgent.identity.principalId : ''

@description('SRE Agent endpoint URL')
output sreAgentEndpoint string = deploySreAgent ? sreAgent.properties.agentEndpoint : ''
