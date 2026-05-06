# Squad Decisions

## Active Decisions

### D1: Architecture Decision — k8s-sre Platform Design

**Author:** Dallas (Lead / Architect)  
**Date:** 2026-05-06  
**Status:** Proposed  

#### Resource Group Structure & Naming Conventions
- **Two-resource-group model:** `rg-k8s-sre-<env>` (primary control plane) + AKS-managed node RG
- **Naming pattern:** `<resource-type>-k8s-sre-<environment>`
- **Environments:** dev, staging, prod
- **Region:** eastus2
- **Tags:** All resources tagged with `project=k8s-sre`, `environment=<env>`, `managed-by=iac`
- **Rationale:** AKS standard practice; clean IaC; quick CLI/portal identification

#### AKS Cluster Configuration
- **SKU:** Standard (uptime SLA; cost-effective)
- **K8s version:** Latest stable (1.30.x)
- **System node pool:** Standard_D4s_v5, 2-3 nodes, System mode
- **User node pool:** Standard_D4s_v5, 1-5 nodes with autoscaler, User mode
- **Networking:** Azure CNI Overlay (pod IPs from overlay, no VNet exhaustion)
- **Network policy:** Azure native (vs Calico)
- **Private cluster:** No (initially)
- **OIDC issuer:** Enabled (required for workload identity)
- **Rationale:** CNI Overlay provides CNI-grade performance without IP planning overhead

#### Log Analytics & Observability
- **Workspace:** Single per env: `log-k8s-sre-<env>`
- **SKU:** PerGB2018 (pay-as-you-go)
- **Retention:** 30 days interactive, 90 days archive
- **Container Insights:** Enabled
- **Diagnostic settings:** AKS control plane logs → Log Analytics
- **Rationale:** Single workspace simplifies RBAC and cross-workspace queries

#### Managed Identity Strategy
- **Approach:** Workload Identity (OIDC federation), not Pod Identity v1 (deprecated)
- **Identities:**
  - `id-k8s-sre-aks-<env>` → AKS kubelet
  - `id-k8s-sre-sre-agent-<env>` → K8s SA `sre-agent/sre-agent-sa`
  - `id-k8s-sre-monitoring-<env>` → K8s SA `monitoring/monitoring-sa`
- **Rationale:** Pod Identity deprecated; Workload Identity is GA, uses industry-standard OIDC

#### Infrastructure-as-Code
- **Choice:** Bicep (not Terraform)
- **Rationale:** Azure-native, zero-state management (ARM handles state), same-day feature support, simpler ops
- **Module structure:** Modular with `modules/` directory; subscription-scoped deployment

#### Deployment Pipeline
- **Choice:** GitHub Actions with environment-based promotion
- **Flow:** PR validate (lint + what-if) → merge → deploy-dev → deploy-staging → deploy-prod
- **OIDC federation:** GitHub Actions → Azure (no stored secrets)
- **Principles:** No direct `az` CLI; all changes via pipeline; GitHub Environments for approval gates

#### SRE Agent Integration
- **Integration:** Managed service connected to AKS + Log Analytics workspace
- **Approach:** Read-only consumer; alert-only (no auto-remediation in v1)
- **Namespace:** `sre-agent` with resource quotas
- **Rationale:** Separates observability production from consumption

### D2: Observability Scaffolding Structure

**Author:** Parker (SRE)  
**Date:** 2026-05-06  
**Status:** Accepted  

- **Directory layout:** `monitoring/` (alerts, dashboards, queries), `sre-agent/`, `runbooks/` — separates observability from infrastructure (Ripley's domain)
- **Bicep for alert rules:** Alert rules parameterized with AKS cluster ID, Log Analytics workspace ID, action group ID
- **Log-based alerts:** Use `scheduledQueryRules` API (2023-03-15-preview) for KQL-based alerts (pod restarts, node NotReady, autoscaler failures)
- **Metric alerts:** Use standard `metricAlerts` API
- **Auto-remediation:** Disabled by default; requires explicit `requireApproval: true` for SRE Agent
- **Severity convention:** Sev 1 = node-level (infrastructure); Sev 2 = pod/workload
- **KQL schema:** ContainerLogV2 used in queries (newer Container Insights schema)
- **Cross-team impact:** Ripley references alert Bicep parameters; team uses runbooks and KQL for incident response

### D3: Azure Infrastructure Scaffold (Bicep)

**Author:** Ripley (Platform Dev)  
**Date:** 2026-05-06  
**Status:** Proposed  

- **Deployment scope:** Subscription-level (`targetScope = 'subscription'`) — RG created by Bicep
- **Networking:** Azure CNI Overlay; pod CIDR `10.244.0.0/16`
- **AKS config:** Workload Identity + OIDC issuer enabled; System pool `Standard_DS2_v2`, 1-3 node autoscaling, AzureLinux
- **Observability:** Log Analytics with Container Insights; omsagent addon wired automatically
- **Security:** Key Vault with RBAC (not access policies); soft delete + purge protection enabled
- **Identity:** User-assigned managed identity for workload federation; principal ID passed to Key Vault
- **Naming:** `${namePrefix}-<suffix>` convention
- **Rationale:** Bicep first-class Azure support; zero-dependency; subscription scope keeps stack declarative

### D4: Infrastructure Scaffold Review — Dallas (Conditional Approve)

**Author:** Dallas (Lead/Architect)  
**Date:** 2026-05-06  
**Status:** Conditional Approve  
**Scope:** Full scaffold review — infra/, monitoring/, sre-agent/, runbooks/

#### Verdict
**CONDITIONAL APPROVE** — Three critical issues must be fixed before first deployment.

#### Critical Blockers (Must Fix)

1. **[#3] Service CIDR Overlap** (infra/modules/aks.bicep)  
   Service CIDR `10.0.8.0/22` overlaps VNet `10.0.0.0/16`. Will fail validation or cause routing conflicts.  
   **Fix:** Change to `172.16.0.0/22` with `dnsServiceIP: '172.16.0.10'`  
   **Owner:** Ripley

2. **[#4] Missing User Node Pool** (infra/modules/aks.bicep)  
   D1 specifies user pool for workloads. System pool only violates AKS best practices.  
   **Fix:** Add user node pool (`Standard_D4s_v5` or `Standard_DS2_v2`, 1–5 nodes, autoscaler)  
   **Owner:** Ripley

3. **[#17] Alert Deployment Gap** (monitoring/alerts/aks-alerts.bicep)  
   Alert rules exist but are not deployed. No deployment path or Action Group.  
   **Fix:** Wire into main.bicep or create separate deploy script with Action Group  
   **Owner:** Parker/Ripley

#### Key Findings Summary

- **infra/main.bicep:** Good (tag value fix: `managed-by: iac` not `bicep`)
- **infra/modules/aks.bicep:** CIDR overlap, missing user pool, VM size mismatch (D4s_v5 not in allowed list), system pool min count=1
- **infra/modules/network.bicep:** Unused pod subnet, no NSG on AKS subnet
- **infra/modules/log-analytics.bicep:** Missing archive-tier retention (30 interactive, 90 archive)
- **infra/modules/identity.bicep:** Only one identity created (need 3 per D1); no federated credentials
- **infra/modules/key-vault.bicep:** Dead access policy code (remove when RBAC enabled); network ACLs open to all
- **monitoring/alerts:** Five good alerts; Sev 2 for node CPU/memory should be Sev 1; missing Action Group module
- **monitoring/queries:** Solid; resource-usage.kql partially commented
- **sre-agent/:** Config uses `kube-system` instead of dedicated `sre-agent` namespace
- **runbooks/:** Excellent; no issues

#### Next Steps
All findings documented with severity levels and owner assignments.

### D5: Alert Rules Wiring into Main Bicep Deployment

**Author:** Ripley (Platform Dev)  
**Date:** 2026-05-06  
**Status:** Proposed  

#### Context
Parker created alert rule definitions in `monitoring/alerts/aks-alerts.bicep` covering 5 critical AKS health signals (node CPU, node memory, pod restarts, node NotReady, autoscaler failures). These needed to be wired into the main infrastructure deployment.

#### Decision
- Created `infra/modules/alerts.bicep` incorporating all 5 alert rules
- Alert module creates inline Action Group (`${namePrefix}-sre-alerts-ag`) with email notification — keeps alerts self-contained
- Metric alerts (CPU, memory) scoped to AKS cluster; log-based alerts scoped to Log Analytics workspace
- Added `deployAlerts` boolean parameter (default: `true`) to main.bicep for environments where alerts aren't needed
- Updated `deploy.sh` with `--no-alerts` flag

#### Trade-offs
- **Inline action group vs. shared:** Chose inline for simplicity. Can extract to shared module if needed later.
- **Parameterized alert email** with default — can be overridden per environment

#### Impact
- Parker: Alert definitions deployed with infra. `monitoring/alerts/aks-alerts.bicep` remains source-of-truth reference; `infra/modules/alerts.bicep` is deployed version.
- Team: `deploy.sh --no-alerts` available for dev/test scenarios

**Files Modified:** `infra/modules/alerts.bicep`, `infra/main.bicep`, `infra/deploy.sh`

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction
