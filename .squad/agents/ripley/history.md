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

### 2026-05-06 — Dallas Review Blockers Fixed
- **Service CIDR overlap (D4 #3):** Changed `serviceCidr` from `10.0.8.0/22` → `172.16.0.0/22`, `dnsServiceIP` → `172.16.0.10`. VNet is `10.0.0.0/16` — no overlap now.
- **User node pool (D4 #4):** Added `user` pool (mode: User, Standard_DS2_v2, 3 fixed nodes, no autoscaling). System pool tainted with `CriticalAddonsOnly=true:NoSchedule`.
- **3-node small config (user directive):** System pool = 1 node (fixed), user pool = 3 nodes (fixed), both Standard_DS2_v2. Autoscaling disabled on both pools.
- **Alert deployment (D4 #17):** Already resolved — `infra/modules/alerts.bicep` wired in `main.bicep` with conditional `deployAlerts` toggle. No changes needed.
- **Pattern:** When using Azure CNI Overlay, service CIDR must be outside VNet address space. Always use a distinct RFC 1918 range (e.g., `172.16.x.x`).
- **Key files modified:** `infra/modules/aks.bicep`, `infra/modules/network.bicep`, `infra/main.bicep`, `infra/main.bicepparam`

### 2026-05-06 — Scribe Coordination: Decisions Consolidated
- **Inbox processed:** 2 files merged (ripley-blocker-fixes.md, copilot-directive-20260506T131623.md)
- **Decisions updated:** D6 (Dallas Review Blockers Resolved) and D7 (User Directive) added to decisions.md
- **Orchestration log:** 20260506T182308Z-ripley.md created documenting blocker fix success
- **Status:** All 3 critical blockers resolved; infra ready for re-review by Dallas

### 2026-05-06 — AKS Infrastructure Deployed to Azure
- **Deployment name:** `k8ssre-dev-deploy` (subscription-scope, eastus2)
- **Fixes applied during deployment (3 iterations):**
  1. **BCP120 scope errors:** `resourceGroup(rg.outputs.resourceGroupName)` is a runtime value; replaced with `resourceGroup(rgName)` using a deterministic variable `var rgName = '${namePrefix}-rg'`
  2. **K8s version 1.30/1.32 LTS-only:** These versions require Premium tier + LTS support plan. Switched to `1.33` (GA, standard support).
  3. **VM SKU `Standard_DS2_v2` unavailable:** Not allowed in this subscription/region. Changed to `Standard_D2s_v3` (equivalent performance, v3 family).
  4. **Alert deployment errors:** Metric alerts failed validation on new cluster (no data yet) — added `skipMetricValidation: true`. KQL `log_s` field doesn't exist in AzureDiagnostics — replaced with `Message`.
- **Resources deployed:**
  - Resource Group: `k8ssre-dev-rg`
  - AKS Cluster: `k8ssre-dev-aks` (FQDN: `k8ssre-dev-aks-dicym0er.hcp.eastus2.azmk8s.io`)
  - VNet: `k8ssre-dev-vnet` (10.0.0.0/16)
  - Log Analytics: `k8ssre-dev-law`
  - Key Vault: `k8ssre-dev-kv` (URI: https://k8ssre-dev-kv.vault.azure.net/)
  - Managed Identity: `k8ssre-dev-identity` (client ID: 68b4c063-1aab-4a8c-8c05-64df8b7a01e5)
  - Action Group: `k8ssre-dev-sre-alerts-ag`
  - Alert Rules: 5 (CPU, memory, pod restarts, node NotReady, autoscaler failures)
  - OIDC Issuer: `https://eastus2.oic.prod-aks.azure.com/b19c3922-8151-4575-af3e-2e6373c43a4e/1f6a5a7c-ae1b-4f7f-87e7-cef773a0613c/`
- **Pattern learned:** Always use `skipMetricValidation: true` for Container Insights metrics on new AKS clusters — data takes ~5 min to appear.
