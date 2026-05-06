// ──────────────────────────────────────────────
// alerts.bicep — AKS alert rules (metric + log-based)
// Wires Parker's alert definitions into the main deployment.
// Owner: Ripley (Platform Dev), alert logic by Parker (SRE)
// Created: 2026-05-06
// ──────────────────────────────────────────────

@description('Azure region for log-based alert resources')
param location string

@description('Naming prefix for resources')
param namePrefix string

@description('Resource tags')
param tags object

@description('Resource ID of the AKS cluster (scope for metric alerts)')
param aksClusterId string

@description('Resource ID of the Log Analytics workspace (scope for log-based alerts)')
param logAnalyticsWorkspaceId string

@description('Environment name')
@allowed([
  'dev'
  'staging'
  'prod'
])
param environment string = 'dev'

@description('Email address for alert notifications')
param alertEmailAddress string = 'sre-team@k8ssre.dev'

// ── Action Group ────────────────────────────
// Provides a notification target for all alert rules.

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: '${namePrefix}-sre-alerts-ag'
  location: 'global'
  tags: tags
  properties: {
    groupShortName: 'sre-alerts'
    enabled: true
    emailReceivers: [
      {
        name: 'SRE Team'
        emailAddress: alertEmailAddress
        useCommonAlertSchema: true
      }
    ]
  }
}

// ── Metric Alert 1: Node CPU > 80% for 5 minutes ──

resource nodeCpuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${namePrefix}-node-cpu-high'
  location: 'global'
  tags: tags
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
          skipMetricValidation: true
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

// ── Metric Alert 2: Node Memory > 80% for 5 minutes ──

resource nodeMemoryAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${namePrefix}-node-memory-high'
  location: 'global'
  tags: tags
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
          skipMetricValidation: true
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

// ── Log Alert 3: Pod restart count > 5 in 15 minutes ──

resource podRestartAlert 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: '${namePrefix}-pod-restart-high'
  location: location
  tags: tags
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
      actionGroups: [actionGroup.id]
    }
  }
}

// ── Log Alert 4: Node NotReady state ──

resource nodeNotReadyAlert 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: '${namePrefix}-node-not-ready'
  location: location
  tags: tags
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
      actionGroups: [actionGroup.id]
    }
  }
}

// ── Log Alert 5: Cluster autoscaler failures ──

resource autoscalerFailureAlert 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: '${namePrefix}-autoscaler-failure'
  location: location
  tags: tags
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
            | where Message has "error" or Message has "failed" or Message has "ScaleUpFailed"
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
      actionGroups: [actionGroup.id]
    }
  }
}

// ── Outputs ─────────────────────────────────

@description('Action group resource ID')
output actionGroupId string = actionGroup.id

@description('Action group name')
output actionGroupName string = actionGroup.name
