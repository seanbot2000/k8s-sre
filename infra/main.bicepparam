using 'main.bicep'

// ──────────────────────────────────────────────
// Dev / Staging defaults for k8s-sre
// Adjust values per environment before deploying.
// ──────────────────────────────────────────────

param location = 'eastus2'
param namePrefix = 'k8ssre-dev'
param environment = 'dev'
param kubernetesVersion = '1.33'
param systemNodeVmSize = 'Standard_D2s_v3'
param systemNodeCount = 1
param userNodeVmSize = 'Standard_D2s_v3'
param userNodeCount = 3
param logRetentionDays = 30
