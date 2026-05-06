# Runbook: Node NotReady

**Severity:** High (Sev 1)
**Owner:** SRE Team
**Last updated:** 2026-05-06

---

## Symptoms

- Alert: `aks-node-not-ready` fires
- `kubectl get nodes` shows one or more nodes in **NotReady** status
- Pods may be evicted or stuck in Pending

## Impact

Workloads on the affected node are disrupted. Kubernetes will not schedule
new pods to the node and may evict existing pods after the toleration period.

## Investigation Steps

### 1. Identify the affected node

```bash
kubectl get nodes -o wide
kubectl describe node <NODE_NAME>
```

### 2. Check node conditions

```bash
kubectl get node <NODE_NAME> -o jsonpath='{.status.conditions[*]}' | jq .
```

Look for:
- `MemoryPressure`, `DiskPressure`, `PIDPressure` → resource exhaustion
- `NetworkUnavailable` → CNI or networking issue
- `KubeletReady = False` → kubelet crash or unresponsive

### 3. Check kubelet logs

```bash
# Via Azure serial console or SSH
journalctl -u kubelet --since "30 minutes ago" --no-pager | tail -100
```

### 4. Run KQL query for node health history

Use `monitoring/queries/node-health.kql` in Log Analytics to see historical data.

### 5. Check Azure resource health

```bash
az aks show -g <RESOURCE_GROUP> -n <CLUSTER_NAME> --query "agentPoolProfiles[].{name:name, count:count, vmSize:vmSize}"
```

## Remediation

### Option A: Cordon and drain the node

```bash
kubectl cordon <NODE_NAME>
kubectl drain <NODE_NAME> --ignore-daemonsets --delete-emptydir-data
```

### Option B: Restart the node via Azure

```bash
# Find the VMSS instance
az vmss list-instances -g <NODE_RESOURCE_GROUP> -n <VMSS_NAME> -o table
az vmss restart -g <NODE_RESOURCE_GROUP> -n <VMSS_NAME> --instance-ids <INSTANCE_ID>
```

### Option C: Delete and let autoscaler replace

```bash
kubectl delete node <NODE_NAME>
# The cluster autoscaler will provision a replacement if needed
```

## Post-Incident

- Verify replacement node is Ready: `kubectl get nodes`
- Confirm workloads rescheduled: `kubectl get pods --all-namespaces -o wide | grep <NODE_NAME>`
- Review root cause (OOM, disk, Azure platform issue) and update alerts if needed
- File incident report if customer-impacting
