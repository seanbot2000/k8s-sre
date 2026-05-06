// ──────────────────────────────────────────────
// Module: Azure Kubernetes Service (AKS)
// ──────────────────────────────────────────────

@description('Azure region for the AKS cluster')
param location string

@description('Resource naming prefix')
param namePrefix string

@description('Tags to apply to all resources')
param tags object = {}

@description('Kubernetes version')
param kubernetesVersion string = '1.30'

@description('AKS subnet resource ID')
param aksSubnetId string

@description('Log Analytics workspace resource ID for Container Insights')
param logAnalyticsWorkspaceId string

@description('System node pool VM size')
@allowed([
  'Standard_D2s_v3'
  'Standard_D4s_v3'
  'Standard_D8s_v3'
])
param systemNodeVmSize string = 'Standard_D2s_v3'

@description('System node pool node count (fixed)')
@minValue(1)
param systemNodeCount int = 1

@description('User node pool VM size')
@allowed([
  'Standard_D2s_v3'
  'Standard_D4s_v3'
  'Standard_D8s_v3'
])
param userNodeVmSize string = 'Standard_D2s_v3'

@description('User node pool node count (fixed)')
@minValue(1)
param userNodeCount int = 3

@description('DNS prefix for the AKS cluster')
param dnsPrefix string = '${namePrefix}-aks'

// ── AKS Cluster ─────────────────────────────

resource aks 'Microsoft.ContainerService/managedClusters@2024-01-01' = {
  name: '${namePrefix}-aks'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: dnsPrefix
    kubernetesVersion: kubernetesVersion

    // ── Networking ────────────────────────────
    networkProfile: {
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
      networkPolicy: 'azure'
      podCidr: '10.244.0.0/16'
      serviceCidr: '172.16.0.0/22'
      dnsServiceIP: '172.16.0.10'
    }

    // ── System Node Pool ──────────────────────
    agentPoolProfiles: [
      {
        name: 'system'
        mode: 'System'
        vmSize: systemNodeVmSize
        count: systemNodeCount
        enableAutoScaling: false
        osType: 'Linux'
        osSKU: 'AzureLinux'
        vnetSubnetID: aksSubnetId
        type: 'VirtualMachineScaleSets'
        nodeTaints: [
          'CriticalAddonsOnly=true:NoSchedule'
        ]
      }
      {
        name: 'user'
        mode: 'User'
        vmSize: userNodeVmSize
        count: userNodeCount
        enableAutoScaling: false
        osType: 'Linux'
        osSKU: 'AzureLinux'
        vnetSubnetID: aksSubnetId
        type: 'VirtualMachineScaleSets'
        nodeTaints: []
      }
    ]

    // ── Security ──────────────────────────────
    oidcIssuerProfile: {
      enabled: true
    }
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }

    // ── Monitoring ────────────────────────────
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspaceId
        }
      }
    }
  }
}

// ── Outputs ─────────────────────────────────

@description('AKS cluster resource ID')
output aksId string = aks.id

@description('AKS cluster name')
output aksName string = aks.name

@description('AKS cluster FQDN')
output aksFqdn string = aks.properties.fqdn

@description('OIDC issuer URL for workload identity federation')
output oidcIssuerUrl string = aks.properties.oidcIssuerProfile.issuerURL

@description('AKS managed identity principal ID')
output aksPrincipalId string = aks.identity.principalId

@description('Kubelet identity object ID')
output kubeletIdentityObjectId string = aks.properties.identityProfile.kubeletidentity.objectId
