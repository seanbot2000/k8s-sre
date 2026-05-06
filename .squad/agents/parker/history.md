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
