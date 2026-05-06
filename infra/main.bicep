// ──────────────────────────────────────────────
// k8s-sre — Main Infrastructure Deployment
// Deploys at subscription scope, creates RG, then all resources.
// ──────────────────────────────────────────────
targetScope = 'subscription'

// ── Parameters ──────────────────────────────

@description('Azure region for all resources')
param location string

@description('Naming prefix applied to all resources (e.g., k8ssre-dev)')
@minLength(3)
@maxLength(20)
param namePrefix string

@description('Environment name')
@allowed([
  'dev'
  'staging'
  'prod'
])
param environment string = 'dev'

@description('Kubernetes version for AKS')
param kubernetesVersion string = '1.30'

@description('System node pool VM size')
@allowed([
  'Standard_D2s_v3'
  'Standard_D4s_v3'
  'Standard_D8s_v3'
])
param systemNodeVmSize string = 'Standard_D2s_v3'

@description('System node pool node count')
@minValue(1)
param systemNodeCount int = 1

@description('User node pool VM size')
@allowed([
  'Standard_D2s_v3'
  'Standard_D4s_v3'
  'Standard_D8s_v3'
])
param userNodeVmSize string = 'Standard_D2s_v3'

@description('User node pool node count')
@minValue(1)
param userNodeCount int = 3

@description('Log Analytics retention in days')
@minValue(30)
@maxValue(730)
param logRetentionDays int = 30

@description('Deploy alert rules for AKS monitoring')
param deployAlerts bool = true

@description('Deploy Azure SRE Agent (standalone service)')
param deploySreAgent bool = true

@description('Email address for alert notifications')
param alertEmailAddress string = 'sre-team@k8ssre.dev'

// ── Tags ────────────────────────────────────

var tags = {
  project: 'k8s-sre'
  environment: environment
  managedBy: 'bicep'
}

var rgName = '${namePrefix}-rg'

// ── Resource Group ──────────────────────────

module rg 'modules/resource-group.bicep' = {
  name: 'deploy-resource-group'
  params: {
    location: location
    namePrefix: namePrefix
    tags: tags
  }
}

// ── Log Analytics ───────────────────────────

module logAnalytics 'modules/log-analytics.bicep' = {
  name: 'deploy-log-analytics'
  scope: resourceGroup(rgName)
  params: {
    location: location
    namePrefix: namePrefix
    tags: tags
    retentionInDays: logRetentionDays
  }
  dependsOn: [rg]
}

// ── Virtual Network ─────────────────────────

module network 'modules/network.bicep' = {
  name: 'deploy-network'
  scope: resourceGroup(rgName)
  params: {
    location: location
    namePrefix: namePrefix
    tags: tags
  }
  dependsOn: [rg]
}

// ── Managed Identity ────────────────────────

module identity 'modules/identity.bicep' = {
  name: 'deploy-identity'
  scope: resourceGroup(rgName)
  params: {
    location: location
    namePrefix: namePrefix
    tags: tags
  }
  dependsOn: [rg]
}

// ── Key Vault ───────────────────────────────

module keyVault 'modules/key-vault.bicep' = {
  name: 'deploy-key-vault'
  scope: resourceGroup(rgName)
  params: {
    location: location
    namePrefix: namePrefix
    tags: tags
    accessPolicyPrincipalId: identity.outputs.principalId
  }
  dependsOn: [identity]
}

// ── AKS Cluster ─────────────────────────────

module aks 'modules/aks.bicep' = {
  name: 'deploy-aks'
  scope: resourceGroup(rgName)
  params: {
    location: location
    namePrefix: namePrefix
    tags: tags
    kubernetesVersion: kubernetesVersion
    systemNodeVmSize: systemNodeVmSize
    systemNodeCount: systemNodeCount
    userNodeVmSize: userNodeVmSize
    userNodeCount: userNodeCount
    aksSubnetId: network.outputs.aksSubnetId
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
  }
  dependsOn: [rg]
}

// ── Alert Rules ─────────────────────────────

module alerts 'modules/alerts.bicep' = if (deployAlerts) {
  name: 'deploy-alerts'
  scope: resourceGroup(rgName)
  params: {
    location: location
    namePrefix: namePrefix
    tags: tags
    aksClusterId: aks.outputs.aksId
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    environment: environment
    alertEmailAddress: alertEmailAddress
  }
}

// ── SRE Agent (Standalone Service) ──────────

module sreAgent 'modules/sre-agent.bicep' = if (deploySreAgent) {
  name: 'deploy-sre-agent'
  scope: resourceGroup(rgName)
  params: {
    location: location
    namePrefix: namePrefix
    tags: tags
    aksClusterId: aks.outputs.aksId
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
  }
  dependsOn: [aks, logAnalytics]
}

// ── Outputs ─────────────────────────────────

@description('Resource group name')
output resourceGroupName string = rgName

@description('AKS cluster name')
output aksClusterName string = aks.outputs.aksName

@description('AKS FQDN')
output aksFqdn string = aks.outputs.aksFqdn

@description('OIDC issuer URL for workload identity')
output oidcIssuerUrl string = aks.outputs.oidcIssuerUrl

@description('Log Analytics workspace ID')
output logAnalyticsWorkspaceId string = logAnalytics.outputs.workspaceId

@description('Key Vault name')
output keyVaultName string = keyVault.outputs.keyVaultName

@description('Key Vault URI')
output keyVaultUri string = keyVault.outputs.keyVaultUri

@description('Managed identity client ID')
output identityClientId string = identity.outputs.clientId

@description('Managed identity name')
output identityName string = identity.outputs.identityName

@description('Action group ID for alert notifications')
output actionGroupId string = (deployAlerts && alerts != null) ? alerts.outputs.actionGroupId : ''

@description('SRE Agent endpoint URL')
output sreAgentEndpoint string = deploySreAgent ? sreAgent.outputs.sreAgentEndpoint : ''

@description('SRE Agent resource ID')
output sreAgentId string = deploySreAgent ? sreAgent.outputs.sreAgentId : ''
