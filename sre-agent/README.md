# Azure SRE Agent — Setup Guide

## Overview

The Azure SRE Agent monitors AKS clusters, auto-investigates alerts, and surfaces
root-cause analysis through Azure Monitor. This guide covers integration with the
k8s-sre project.

## Prerequisites

- Azure subscription with **Owner** or **Contributor** role
- AKS cluster with Container Insights enabled
- Log Analytics workspace configured and receiving data
- Azure Monitor action group for alert routing

## Setup Steps

### 1. Enable Container Insights on AKS

```bash
az aks enable-addons \
  --resource-group <RESOURCE_GROUP> \
  --name <CLUSTER_NAME> \
  --addons monitoring \
  --workspace-resource-id <LOG_ANALYTICS_WORKSPACE_ID>
```

### 2. Register the SRE Agent preview feature

```bash
az feature register \
  --namespace Microsoft.ContainerService \
  --name SreAgentPreview

# Wait for registration, then propagate
az provider register --namespace Microsoft.ContainerService
```

### 3. Deploy the SRE Agent configuration

Use the `config.yaml` in this directory as a starting template.
Customize thresholds and investigation scopes to match your environment.

```bash
# Apply the config (adjust path if needed)
kubectl apply -f sre-agent/config.yaml
```

### 4. Verify integration

```bash
# Check SRE Agent pods
kubectl get pods -n kube-system -l app=sre-agent

# Verify logs
kubectl logs -n kube-system -l app=sre-agent --tail=50
```

## Configuration Reference

| Setting                    | Description                          | Default     |
|----------------------------|--------------------------------------|-------------|
| `investigationScope`       | Namespaces the agent monitors        | All         |
| `alertIntegration.enabled` | Route alerts through SRE Agent       | `true`      |
| `autoRemediation.enabled`  | Allow automated fix actions          | `false`     |
| `logRetentionDays`         | Days to keep investigation logs      | `30`        |

## Related Resources

- [Azure SRE Agent Documentation](https://learn.microsoft.com/en-us/azure/aks/sre-agent-overview)
- [Container Insights](https://learn.microsoft.com/en-us/azure/azure-monitor/containers/container-insights-overview)
- Alert rules: `../monitoring/alerts/aks-alerts.bicep`
- Runbooks: `../runbooks/`
