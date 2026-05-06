# k8s-sre: Azure AKS SRE Platform

An Infrastructure as Code platform for running and observing Azure Kubernetes Service (AKS) clusters with integrated SRE capabilities.

## Overview

This project provides a complete Azure AKS environment with:

- **Infrastructure as Code**: Modular Bicep templates for reproducible AKS cluster deployment
- **Observability**: Log Analytics and Container Insights for cluster monitoring and diagnostics
- **Stress Testing**: Memory pressure and load testing utilities for validating cluster resilience
- **SRE Agent Integration**: Standalone Azure service for automated incident response and platform health checks

## Stack

- **Container Orchestration**: Azure AKS (3-node cluster, D2s_v3 VMs)
- **Infrastructure**: Bicep IaC with modular templates
- **Monitoring**: Azure Log Analytics, Container Insights
- **Queries**: Kusto Query Language (KQL) for log analysis
- **Testing**: Custom stress test utilities

## Project Structure

```
├── infra/           # Bicep IaC templates
├── k8s/             # Kubernetes manifests and workloads
├── monitoring/      # Log Analytics queries and alert rules
├── sre-agent/       # SRE Agent service configuration
├── runbooks/        # Incident response and operational runbooks
└── deploy.sh        # Deployment script
```

## Quick Start

Deploy the AKS cluster and monitoring infrastructure:

```bash
./deploy.sh
```

## License

MIT License - see [LICENSE](LICENSE) file for details.
