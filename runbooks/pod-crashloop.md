# Runbook: Pod CrashLoopBackOff

**Severity:** Medium–High (Sev 2–3)
**Owner:** SRE Team
**Last updated:** 2026-05-06

---

## Symptoms

- Alert: `aks-pod-restart-high` fires
- `kubectl get pods` shows pod in **CrashLoopBackOff** status
- Pod restart count is climbing

## Impact

The affected workload is unavailable or degraded. If the pod belongs to a
Deployment with multiple replicas, partial availability may remain.

## Investigation Steps

### 1. Identify the crashing pod

```bash
kubectl get pods --all-namespaces --field-selector=status.phase!=Running | grep -v Completed
```

### 2. Check pod events and status

```bash
kubectl describe pod <POD_NAME> -n <NAMESPACE>
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.status.containerStatuses[*]}' | jq .
```

Look for:
- `OOMKilled` → container exceeds memory limit
- `Error` → application crash
- `ImagePullBackOff` → wrong image tag or registry auth failure
- `CrashLoopBackOff` → container starts and immediately exits

### 3. Check container logs

```bash
# Current container logs
kubectl logs <POD_NAME> -n <NAMESPACE> --tail=100

# Previous container (crashed) logs
kubectl logs <POD_NAME> -n <NAMESPACE> --previous --tail=100
```

### 4. Run KQL query

Use `monitoring/queries/pod-failures.kql` in Log Analytics for broader crash patterns.

### 5. Check resource limits

```bash
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.containers[*].resources}' | jq .
```

## Remediation

### OOMKilled

1. Increase memory limits in the pod spec or Helm values
2. Investigate memory leaks in the application
3. Redeploy: `kubectl rollout restart deployment/<DEPLOYMENT_NAME> -n <NAMESPACE>`

### Application Error

1. Review application logs (Step 3 above)
2. Check recent deployments: `kubectl rollout history deployment/<DEPLOYMENT_NAME> -n <NAMESPACE>`
3. Roll back if caused by a recent change: `kubectl rollout undo deployment/<DEPLOYMENT_NAME> -n <NAMESPACE>`

### ImagePullBackOff

1. Verify image exists: `az acr repository show-tags -n <ACR_NAME> --repository <IMAGE>`
2. Check pull secret: `kubectl get secret -n <NAMESPACE>`
3. Verify AKS → ACR integration: `az aks check-acr -g <RG> -n <CLUSTER> --acr <ACR_NAME>`

### Liveness/Readiness Probe Failure

1. Check probe configuration in pod spec
2. Verify the health endpoint responds: `kubectl exec <POD_NAME> -n <NAMESPACE> -- curl -s localhost:<PORT>/health`
3. Adjust probe `initialDelaySeconds` or `timeoutSeconds` if the app is slow to start

## Post-Incident

- Confirm pod is stable: `kubectl get pod <POD_NAME> -n <NAMESPACE> -w`
- Review restart history to ensure the issue is resolved
- Update resource limits or probe config in source control
- File incident report if customer-impacting
