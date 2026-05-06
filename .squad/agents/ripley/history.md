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

### 2026-05-06 — Alert Rules Wired into Main Deployment
- **What:** Created `infra/modules/alerts.bicep` from Parker's `monitoring/alerts/aks-alerts.bicep` definitions
- **Alert module receives:** `aksClusterId` (from aks.bicep), `logAnalyticsWorkspaceId` (from log-analytics.bicep), `environment`, `alertEmailAddress`
- **Scoping:** Metric alerts (CPU, memory) scoped to AKS cluster ID; log-based alerts (pod restarts, node NotReady, autoscaler) scoped to Log Analytics workspace ID
- **Action Group:** Created inline in alerts module (`${namePrefix}-sre-alerts-ag`) — avoids external dependency
- **Toggle:** `deployAlerts` boolean parameter (default: true) on main.bicep; `--no-alerts` flag in deploy.sh
- **Key files:**
  - `infra/modules/alerts.bicep` — 5 alert rules + action group
  - `infra/main.bicep` — wires alerts module after AKS + Log Analytics
  - `deploy.sh` — passes `deployAlerts` param, supports `--no-alerts`
- **Pattern:** Conditional module deployment via `= if (deployAlerts)` with ternary on outputs

## Team Updates

### 2026-05-06 — Squad Decisions Merged
- D3 (Infrastructure Scaffold) merged into `.squad/decisions.md`
- Dallas confirmed: Bicep choice aligned with architecture decisions; subscription scope validated
- Parker coordinated: Alert Bicep templates reference Ripley's Log Analytics workspace output
- Cross-team coordination: Infrastructure decisions formalized; Ripley ready for module implementation

### 2026-05-06 — Decision Review & Blockers Identified (Scribe Coordination)
- **Decisions merged:** D4 (Dallas review) and D5 (Alert wiring) finalized in decisions.md
- **Critical blockers for Ripley (3):**
  1. Service CIDR overlap: `serviceCidr` 10.0.8.0/22 overlaps VNet 10.0.0.0/16 → Change to 172.16.0.0/22 (aks.bicep)
  2. Missing user node pool: Add user pool (D4s_v5 or DS2_v2, 1–5 nodes, autoscaler) to aks.bicep
  3. Archive retention on Log Analytics: Implement 30-day interactive / 90-day archive retention (log-analytics.bicep)
- **Orchlogs generated:** `2026-05-06-180000Z-ripley.md` (background success documented)
- **Next:** Prioritize critical fixes before first deployment
