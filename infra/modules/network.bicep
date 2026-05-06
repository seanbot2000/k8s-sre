// ──────────────────────────────────────────────
// Module: Virtual Network + Subnets for AKS
// ──────────────────────────────────────────────

@description('Azure region for the VNet')
param location string

@description('Resource naming prefix')
param namePrefix string

@description('Tags to apply to all resources')
param tags object = {}

@description('VNet address space')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('AKS subnet address prefix')
param aksSubnetPrefix string = '10.0.0.0/22'

@description('Pod subnet address prefix (for Azure CNI Overlay)')
param podSubnetPrefix string = '10.0.4.0/22'

// ── Virtual Network ─────────────────────────

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: '${namePrefix}-vnet'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'aks-subnet'
        properties: {
          addressPrefix: aksSubnetPrefix
        }
      }
      {
        name: 'pod-subnet'
        properties: {
          addressPrefix: podSubnetPrefix
          delegations: []
        }
      }
    ]
  }
}

// ── Outputs ─────────────────────────────────

@description('Resource ID of the VNet')
output vnetId string = vnet.id

@description('Name of the VNet')
output vnetName string = vnet.name

@description('Resource ID of the AKS subnet')
output aksSubnetId string = vnet.properties.subnets[0].id

@description('Resource ID of the Pod subnet')
output podSubnetId string = vnet.properties.subnets[1].id
