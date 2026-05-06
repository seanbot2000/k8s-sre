// ──────────────────────────────────────────────
// Module: Log Analytics Workspace + Container Insights
// ──────────────────────────────────────────────

@description('Azure region for the workspace')
param location string

@description('Resource naming prefix')
param namePrefix string

@description('Tags to apply to all resources')
param tags object = {}

@description('Workspace data retention in days')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

@description('Log Analytics SKU')
@allowed([
  'PerGB2018'
  'Free'
  'Standalone'
])
param sku string = 'PerGB2018'

// ── Log Analytics Workspace ─────────────────

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${namePrefix}-law'
  location: location
  tags: tags
  properties: {
    sku: {
      name: sku
    }
    retentionInDays: retentionInDays
  }
}

// ── Container Insights Solution ─────────────

resource containerInsights 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'ContainerInsights(${logAnalytics.name})'
  location: location
  tags: tags
  plan: {
    name: 'ContainerInsights(${logAnalytics.name})'
    publisher: 'Microsoft'
    product: 'OMSGallery/ContainerInsights'
    promotionCode: ''
  }
  properties: {
    workspaceResourceId: logAnalytics.id
  }
}

// ── Outputs ─────────────────────────────────

@description('Resource ID of the Log Analytics workspace')
output workspaceId string = logAnalytics.id

@description('Name of the Log Analytics workspace')
output workspaceName string = logAnalytics.name

@description('Customer ID (workspace ID) for agent configuration')
output workspaceCustomerId string = logAnalytics.properties.customerId
