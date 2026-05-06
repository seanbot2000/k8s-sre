# Parker — History

## Project Context
- **Project:** k8s-sre — AKS cluster, Azure SRE Agent, and Log Analytics
- **Stack:** Azure (AKS, Log Analytics, Azure Monitor), Bicep/Terraform, Kubernetes
- **User:** Seanbot200
- **Created:** 2026-05-06

## Learnings

### 2026-05-06 — SRE Agent Deployment Attempted
- **Log Analytics Workspace ID:** `97568188-11b7-4132-9f13-d854b122b7c3` (workspace: k8ssre-dev-law)
- **Action Group ID:** `/subscriptions/3E3AF423-CB5A-441F-A172-98B442A07D8B/resourceGroups/k8ssre-dev-rg/providers/microsoft.insights/actionGroups/k8ssre-dev-sre-alerts-ag`
- **SRE Agent Feature Status:** `SreAgentPreview` feature NOT FOUND in subscription — Azure SRE Agent is in limited preview and not yet available for this subscription.
- **Container Insights:** ENABLED on k8ssre-dev-aks, using k8ssre-dev-law workspace with managed identity (omsagent).
- **Config updated:** `sre-agent/config.yaml` now contains real values (no more placeholders).
- **kubectl apply:** FAILED — CRD `sre.azure.com/v1alpha1/SreAgentConfig` does not exist on cluster yet. Created `sre-agent/deploy.sh` for when feature becomes available.
- **Monitoring state:** Container Insights active, metric alerts deployed via Bicep, SRE Agent pending preview access.

### 2026-05-06 — Observability Scaffolding Created
- **Alert rules** in Bicep at `monitoring/alerts/aks-alerts.bicep` — 5 alerts covering node CPU/memory, pod restarts, node NotReady, and autoscaler failures. Metric alerts use `Microsoft.Insights/metricAlerts`; log-based alerts use `Microsoft.Insights/scheduledQueryRules`.
- **KQL queries** at `monitoring/queries/` — 4 saved queries (pod-failures, node-health, container-logs, resource-usage). Uses `ContainerLogV2` for log search (v2 schema).
- **SRE Agent config** at `sre-agent/` — YAML config template with placeholder env vars. Auto-remediation disabled by default; requires `requireApproval: true` before enabling.
- **Runbooks** at `runbooks/` — Node NotReady and Pod CrashLoopBackOff procedures. Reference the KQL queries for investigation.
- **Dashboards** directory at `monitoring/dashboards/` — placeholder `.gitkeep`; workbook templates to be added when dashboard requirements are defined.
- Alert severity convention: Sev 1 for node-level issues (NotReady), Sev 2 for pod/autoscaler issues.

## Team Updates

### 2026-05-06 — Squad Decisions Merged
- D2 (Observability Scaffolding) merged into `.squad/decisions.md`
- Dallas coordinated: SRE Agent as read-only consumer of Log Analytics data; alert routing to Action Group
- Ripley provided: Log Analytics workspace ID and OIDC issuer URL from Bicep scaffolding
- Cross-team coordination: Observability decisions formalized; Parker ready for alert rule refinement

### 2026-05-06 — Alert Integration & Design Decisions Finalized (Scribe Coordination)
- **D5 Alert Wiring** finalized and merged into decisions.md
- **Ripley completed:** Alert integration into main.bicep — `infra/modules/alerts.bicep` now wires all 5 Parker-designed alerts into deployment
- **Decisions recorded:**
  - Source-of-truth: `monitoring/alerts/aks-alerts.bicep` (Parker maintains alert definitions)
  - Deployed version: `infra/modules/alerts.bicep` (Ripley maintains deployment copy)
  - Inline Action Group (`${namePrefix}-sre-alerts-ag`) with parameterized email
  - `deployAlerts` toggle in main.bicep; `--no-alerts` flag in deploy.sh
- **D4 review identified moderate issues for Parker:**
  - Node CPU/memory severity should be Sev 1 (not Sev 2) — fix in aks-alerts.bicep
  - Add `project: 'k8s-sre'` tag to align with infra conventions
  - Create Action Group Bicep module (currently no AMRM resource exists)
  - Move SRE Agent to dedicated `sre-agent` namespace (currently kube-system)
- **Orchlog generated:** Dallas's review findings documented
- **Next:** Await Ripley's critical fixes; then address Parker's moderate items

### 2026-05-06 — Azure SRE Agent Deployed as Standalone Service
- **Resource Type:** `Microsoft.App/agents` (API version `2025-05-01-preview`)
- **Resource Name:** `k8ssre-dev-sre-agent`
- **Resource ID:** `/subscriptions/3e3af423-cb5a-441f-a172-98b442a07d8b/resourceGroups/k8ssre-dev-rg/providers/Microsoft.App/agents/k8ssre-dev-sre-agent`
- **Endpoint:** `https://k8ssre-dev-sre-agent--c08bdf84.de5105f9.eastus2.azuresre.ai`
- **Identity:** SystemAssigned managed identity (principalId: `f77a05d6-72d7-414a-b418-a36b61b114de`)
- **Provisioning:** Succeeded; runningState: BuildingKnowledgeGraph
- **RBAC Grants:**
  - Reader on resource group `k8ssre-dev-rg`
  - Azure Kubernetes Service Cluster User Role on AKS cluster
  - Log Analytics Reader on `k8ssre-dev-law`
- **What DIDN'T work:**
  - `sreAgents/default` child resource under AKS (404 on all API versions)
  - `sreAgentProfile` property on AKS PATCH (silently ignored — not a real property)
  - `connectedClusterResourceId` property (not recognized by the API)
  - `agentAppEnvelope` wrapper (not the correct body shape)
  - `monitoredResourceGroups` and `description` properties (not supported in AgentView)
- **What WORKED:**
  - `PUT /providers/Microsoft.App/agents/{name}?api-version=2025-05-01-preview`
  - Body: `{"location":"eastus2","identity":{"type":"SystemAssigned"},"properties":{}}`
  - The agent is NOT a child of AKS — it's an independent resource in the same RG
  - RBAC grants give it access to observe AKS + Log Analytics externally
- **Bicep module:** `infra/modules/sre-agent.bicep` — wired into `main.bicep` with `deploySreAgent` toggle
- **Key insight:** SRE Agent uses scope-based access via managed identity RBAC, not explicit resource linking
