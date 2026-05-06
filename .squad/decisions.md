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

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction
