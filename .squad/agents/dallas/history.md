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

## Team Updates

### 2026-05-06 — Squad Decisions Merged
- D1 (Architecture Design) merged into `.squad/decisions.md`
- Parker aligned: SRE Agent read-only consumer; alert routing to Action Group
- Ripley aligned: Bicep subscription-scoped approach; parameter passing strategy
- Cross-team coordination: Architecture decisions formalized; team ready for implementation phase
