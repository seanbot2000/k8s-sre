#!/bin/bash
# SRE Agent Deployment Script
# Owner: Parker (SRE)
# Created: 2026-05-06
#
# Prerequisites:
#   - Azure CLI authenticated with appropriate permissions
#   - kubectl configured for the target cluster
#   - SreAgentPreview feature registered (see below)
#
# Usage: ./sre-agent/deploy.sh

set -euo pipefail

RESOURCE_GROUP="k8ssre-dev-rg"
CLUSTER_NAME="k8ssre-dev-aks"
SUBSCRIPTION_ID="3e3af423-cb5a-441f-a172-98b442a07d8b"

echo "=== Azure SRE Agent Deployment ==="

# Step 1: Check/register SRE Agent preview feature
echo "[1/4] Checking SreAgentPreview feature registration..."
FEATURE_STATE=$(az feature show --namespace Microsoft.ContainerService --name SreAgentPreview --query "properties.state" -o tsv 2>/dev/null || echo "NotFound")

if [ "$FEATURE_STATE" = "NotFound" ]; then
    echo "ERROR: SreAgentPreview feature not found in this subscription."
    echo "       The Azure SRE Agent is in limited preview. Request access at:"
    echo "       https://aka.ms/aks/sre-agent-preview"
    exit 1
elif [ "$FEATURE_STATE" != "Registered" ]; then
    echo "Feature state: $FEATURE_STATE — registering..."
    az feature register --namespace Microsoft.ContainerService --name SreAgentPreview
    az provider register --namespace Microsoft.ContainerService
    echo "Waiting for feature registration (this can take several minutes)..."
    az feature show --namespace Microsoft.ContainerService --name SreAgentPreview --query "properties.state" -o tsv
fi

# Step 2: Ensure kubeconfig is set
echo "[2/4] Configuring kubectl..."
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --overwrite-existing

# Step 3: Verify CRD exists
echo "[3/4] Checking for SreAgentConfig CRD..."
if ! kubectl get crd sreagentconfigs.sre.azure.com &>/dev/null; then
    echo "ERROR: SreAgentConfig CRD not found on cluster."
    echo "       Ensure the SRE Agent extension is installed on the cluster:"
    echo "       az aks update -g $RESOURCE_GROUP -n $CLUSTER_NAME --enable-sre-agent"
    exit 1
fi

# Step 4: Apply configuration
echo "[4/4] Applying SRE Agent configuration..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$SCRIPT_DIR/config.yaml"

echo ""
echo "=== SRE Agent deployed successfully ==="
echo "Verify with: kubectl get sreagentconfig -n kube-system"
