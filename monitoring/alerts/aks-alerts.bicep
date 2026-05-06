// AKS Alert Rules — Metric and log-based alerts for cluster health
// Owner: Parker (SRE)
// Created: 2026-05-06

@description('Resource ID of the AKS cluster to monitor')
param aksClusterId string

@description('Resource ID of the Log Analytics workspace')
param logAnalyticsWorkspaceId string

@description('Resource ID of the Action Group for alert notifications')
param actionGroupId string

@description('Environment tag')
param environment string = 'production'

var commonTags = {
  owner: 'sre'
  environment: environment
  managedBy: 'bicep'
}

// ============================================================
// Alert 1: Node CPU > 80% for 5 minutes
// ============================================================
resource nodeCpuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'aks-node-cpu-high'
  location: 'global'
  tags: commonTags
  properties: {
    description: 'Alert when node CPU usage exceeds 80% for 5 minutes'
    severity: 2
    enabled: true
    scopes: [aksClusterId]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'NodeCpuHigh'
          metricName: 'node_cpu_usage_percentage'
          metricNamespace: 'Insights.Container/nodes'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroupId
      }
    ]
  }
}

// ============================================================
// Alert 2: Node Memory > 80% for 5 minutes
// ============================================================
resource nodeMemoryAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'aks-node-memory-high'
  location: 'global'
  tags: commonTags
  properties: {
    description: 'Alert when node memory usage exceeds 80% for 5 minutes'
    severity: 2
    enabled: true
    scopes: [aksClusterId]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'NodeMemoryHigh'
          metricName: 'node_memory_working_set_percentage'
          metricNamespace: 'Insights.Container/nodes'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroupId
      }
    ]
  }
}

// ============================================================
// Alert 3: Pod restart count > 5 in 15 minutes
// ============================================================
resource podRestartAlert 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: 'aks-pod-restart-high'
  location: resourceGroup().location
  tags: commonTags
  properties: {
    description: 'Alert when a pod restarts more than 5 times in 15 minutes'
    severity: 2
    enabled: true
    scopes: [logAnalyticsWorkspaceId]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      allOf: [
        {
          query: '''
            KubePodInventory
            | where PodRestartCount > 5
            | summarize RestartCount = max(PodRestartCount) by PodName = Name, Namespace, ClusterName, bin(TimeGenerated, 15m)
            | where RestartCount > 5
          '''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [actionGroupId]
    }
  }
}

// ============================================================
// Alert 4: Node NotReady state
// ============================================================
resource nodeNotReadyAlert 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: 'aks-node-not-ready'
  location: resourceGroup().location
  tags: commonTags
  properties: {
    description: 'Alert when any node enters NotReady state'
    severity: 1
    enabled: true
    scopes: [logAnalyticsWorkspaceId]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          query: '''
            KubeNodeInventory
            | where Status == "NotReady"
            | summarize NotReadyCount = dcount(Computer) by ClusterName, bin(TimeGenerated, 5m)
            | where NotReadyCount > 0
          '''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [actionGroupId]
    }
  }
}

// ============================================================
// Alert 5: Cluster autoscaler failures
// ============================================================
resource autoscalerFailureAlert 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: 'aks-autoscaler-failure'
  location: resourceGroup().location
  tags: commonTags
  properties: {
    description: 'Alert on cluster autoscaler failures'
    severity: 2
    enabled: true
    scopes: [logAnalyticsWorkspaceId]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      allOf: [
        {
          query: '''
            AzureDiagnostics
            | where Category == "cluster-autoscaler"
            | where log_s has "error" or log_s has "failed" or log_s has "ScaleUpFailed"
            | summarize FailureCount = count() by ClusterName = Resource, bin(TimeGenerated, 15m)
            | where FailureCount > 0
          '''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [actionGroupId]
    }
  }
}
