#!/usr/bin/env bash
# ──────────────────────────────────────────────
# deploy.sh — Deploy k8s-sre Azure infrastructure
# Usage:  ./deploy.sh [--location <region>] [--prefix <name>] [--env <dev|staging|prod>]
# ──────────────────────────────────────────────
set -euo pipefail

LOCATION="${LOCATION:-eastus2}"
NAME_PREFIX="${NAME_PREFIX:-k8ssre-dev}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
DEPLOY_ALERTS="${DEPLOY_ALERTS:-true}"
DEPLOYMENT_NAME="k8ssre-$(date +%Y%m%d-%H%M%S)"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --location)  LOCATION="$2";      shift 2 ;;
    --prefix)    NAME_PREFIX="$2";    shift 2 ;;
    --env)       ENVIRONMENT="$2";    shift 2 ;;
    --no-alerts) DEPLOY_ALERTS="false"; shift ;;
    -h|--help)
      echo "Usage: $0 [--location <region>] [--prefix <name>] [--env <dev|staging|prod>] [--no-alerts]"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "═══════════════════════════════════════════"
echo "  k8s-sre Infrastructure Deployment"
echo "═══════════════════════════════════════════"
echo "  Location:    $LOCATION"
echo "  Prefix:      $NAME_PREFIX"
echo "  Environment: $ENVIRONMENT"
echo "  Alerts:      $DEPLOY_ALERTS"
echo "  Deployment:  $DEPLOYMENT_NAME"
echo "═══════════════════════════════════════════"

# Ensure logged in
echo ""
echo "→ Checking Azure CLI login..."
az account show --output table || { echo "ERROR: Not logged into Azure CLI. Run 'az login' first."; exit 1; }

# Validate the template first
echo ""
echo "→ Validating Bicep template..."
az deployment sub validate \
  --location "$LOCATION" \
  --template-file "$SCRIPT_DIR/infra/main.bicep" \
  --parameters \
    location="$LOCATION" \
    namePrefix="$NAME_PREFIX" \
    environment="$ENVIRONMENT" \
    deployAlerts="$DEPLOY_ALERTS" \
  --output table

# Deploy
echo ""
echo "→ Deploying infrastructure..."
az deployment sub create \
  --name "$DEPLOYMENT_NAME" \
  --location "$LOCATION" \
  --template-file "$SCRIPT_DIR/infra/main.bicep" \
  --parameters \
    location="$LOCATION" \
    namePrefix="$NAME_PREFIX" \
    environment="$ENVIRONMENT" \
    deployAlerts="$DEPLOY_ALERTS" \
  --output table

echo ""
echo "→ Fetching AKS credentials..."
RG_NAME="${NAME_PREFIX}-rg"
AKS_NAME="${NAME_PREFIX}-aks"
az aks get-credentials \
  --resource-group "$RG_NAME" \
  --name "$AKS_NAME" \
  --overwrite-existing

echo ""
echo "✅ Deployment complete!"
echo "   kubectl context set to: $AKS_NAME"
echo ""
echo "   Key outputs:"
az deployment sub show \
  --name "$DEPLOYMENT_NAME" \
  --query "properties.outputs" \
  --output table 2>/dev/null || echo "   (run 'az deployment sub show --name $DEPLOYMENT_NAME' to see outputs)"
