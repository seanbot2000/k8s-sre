# Parker — History

## Project Context
- **Project:** k8s-sre — AKS cluster, Azure SRE Agent, and Log Analytics
- **Stack:** Azure (AKS, Log Analytics, Azure Monitor), Bicep/Terraform, Kubernetes
- **User:** Seanbot200
- **Created:** 2026-05-06

## Learnings

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
