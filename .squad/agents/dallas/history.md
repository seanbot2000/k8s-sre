# Dallas — History

## Project Context
- **Project:** k8s-sre — AKS cluster, Azure SRE Agent, and Log Analytics
- **Stack:** Azure (AKS, Log Analytics, Azure Monitor), Bicep/Terraform, Kubernetes
- **User:** Seanbot200
- **Created:** 2026-05-06

## Learnings

### 2026-05-06 — Initial Architecture Design
- **Architecture doc written to:** `.squad/decisions/inbox/dallas-architecture-design.md`
- **Key decisions:** Bicep over Terraform (Azure-only, stateless), Azure CNI Overlay networking, Workload Identity (Pod Identity deprecated), Standard AKS SKU, single Log Analytics workspace per env, GitHub Actions with OIDC federation
- **Resource naming pattern:** `<resource-type>-k8s-sre-<env>` (e.g., `aks-k8s-sre-dev`)
- **Bicep module structure:** `infra/main.bicep` orchestrator with modules under `infra/modules/`
- **Team assignments:** Ripley owns Bicep implementation, Parker owns SRE Agent config, Lambert owns test harness
- **User preference:** Seanbot200 requested architecture-only (no code from Dallas — delegates to Ripley/Parker)
- **SRE Agent stance:** Alert-only in v1, no auto-remediation until trust is established

### 2026-05-06 — Infrastructure Scaffold Review
- **Review written to:** `.squad/decisions/inbox/dallas-infra-review.md`
- **Verdict:** Conditional Approve — 3 critical issues block deployment
- **Critical findings:**
  - AKS serviceCidr (10.0.8.0/22) overlaps VNet address space (10.0.0.0/16) — will fail validation or cause routing issues
  - No user node pool defined despite D1 requiring one — workloads would compete with system pods
  - Alert rules (aks-alerts.bicep) exist but have no deployment path — never wired into main.bicep or scripts
- **Quality observations:**
  - Ripley's Bicep structure is clean and well-organized; module interfaces are consistent
  - Parker's KQL queries correctly use ContainerLogV2 schema; alert coverage is solid
  - Runbooks are the strongest deliverable — well-structured, actionable, cross-referenced
  - Key Vault has contradictory config: RBAC enabled but access policies also defined (dead code)
  - Identity module only creates one identity; D1 requires three with federated credentials
  - Tag values don't fully align with D1 conventions (managedBy vs managed-by, iac vs bicep)
- **Pattern noticed:** D1 vs D3 have minor spec divergences (VM sizes, min node counts) — need to reconcile decisions to avoid ambiguity for implementers

## Team Updates

### 2026-05-06 — Squad Decisions Merged
- D1 (Architecture Design) merged into `.squad/decisions.md`
- Parker aligned: SRE Agent read-only consumer; alert routing to Action Group
- Ripley aligned: Bicep subscription-scoped approach; parameter passing strategy
- Cross-team coordination: Architecture decisions formalized; team ready for implementation phase

### 2026-05-06 — Review Finalized & Conditional Approve Recorded (Scribe Coordination)
- **D4 Infrastructure Scaffold Review** finalized and merged into decisions.md
- **Verdict documented:** Conditional Approve — 3 critical blockers identified
- **Critical blockers assigned to Ripley (blocking deployment):**
  1. Service CIDR overlap (aks.bicep line 43)
  2. Missing user node pool (aks.bicep)
  3. Alert deployment gap (monitoring/alerts — needs main.bicep wiring)
- **Total findings:** 24 (3 critical, 6 moderate, 8 minor, 7 backlog)
- **Orchlog generated:** `2026-05-06-180000Z-dallas.md` (background success documented)
- **Pattern noted:** D1 vs D3 divergences (VM sizes, node counts) will need reconciliation post-fixes
- **Next:** Team awaits Ripley's fixes; Dallas to re-review before prod deployment

### 2026-05-06 — Final Review: All Blockers Approved
- **Verdict:** APPROVE — all 3 critical blockers from D4 resolved cleanly
- **Blocker 1 (CIDR overlap):** Service CIDR moved to 172.16.0.0/22, fully outside VNet 10.0.0.0/16. DNS IP correctly within range.
- **Blocker 2 (User node pool):** Added with mode=User, 3× Standard_DS2_v2, no autoscaling. System pool tainted CriticalAddonsOnly.
- **Blocker 3 (Alert deployment):** Wired into main.bicep with conditional toggle, correct resource ID passthrough, proper dependency chain.
- **Quality observation:** Ripley's fixes are surgical — minimal changes, no regressions introduced. Parameters file and deploy.sh both consistent.
- **Remaining backlog:** Tag naming convention mismatch (cosmetic), unused pod subnet (harmless), identity count gap (D1 specifies 3, only 1 exists)
- **Decision written to:** `.squad/decisions/inbox/dallas-final-review.md`
