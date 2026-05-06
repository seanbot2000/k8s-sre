# Ripley — History

## Project Context
- **Project:** k8s-sre — AKS cluster, Azure SRE Agent, and Log Analytics
- **Stack:** Azure (AKS, Log Analytics, Azure Monitor), Bicep/Terraform, Kubernetes
- **User:** Seanbot200
- **Created:** 2026-05-06

## Learnings

### 2026-05-06 — Infrastructure Scaffold Created
- **Stack:** Bicep, subscription-scoped deployment
- **Key files:**
  - `infra/main.bicep` — orchestrator (subscription scope, wires all modules)
  - `infra/main.bicepparam` — dev/staging parameter defaults
  - `infra/modules/resource-group.bicep` — RG creation
  - `infra/modules/network.bicep` — VNet + AKS/Pod subnets
  - `infra/modules/log-analytics.bicep` — Log Analytics + Container Insights solution
  - `infra/modules/aks.bicep` — AKS cluster (CNI Overlay, Workload Identity, OIDC, autoscale)
  - `infra/modules/identity.bicep` — User-assigned managed identity
  - `infra/modules/key-vault.bicep` — Key Vault (RBAC auth, soft delete, purge protection)
  - `deploy.sh` — CLI wrapper for validation + deployment
- **Naming convention:** `${namePrefix}-<suffix>` (e.g., `k8ssre-dev-aks`)
- **Networking:** Azure CNI Overlay; VNet `10.0.0.0/16`, AKS subnet `/22`, Pod CIDR `10.244.0.0/16`
- **AKS:** System pool `Standard_DS2_v2`, 1-3 nodes autoscale, AzureLinux OS, OIDC + Workload Identity enabled
- **Cross-module outputs:** `oidcIssuerUrl`, `logAnalyticsWorkspaceId`, `identityClientId` available for downstream use

## Team Updates

### 2026-05-06 — Squad Decisions Merged
- D3 (Infrastructure Scaffold) merged into `.squad/decisions.md`
- Dallas confirmed: Bicep choice aligned with architecture decisions; subscription scope validated
- Parker coordinated: Alert Bicep templates reference Ripley's Log Analytics workspace output
- Cross-team coordination: Infrastructure decisions formalized; Ripley ready for module implementation
