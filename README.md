# HOMELAB

A self-hosted infrastructure platform built around Kubernetes, GitOps, and declarative configuration.

[![Super-Linter](https://github.com/shatadru/homelab/actions/workflows/super-linter.yml/badge.svg)](https://github.com/shatadru/homelab/actions/workflows/super-linter.yml)
[![Renovate](https://img.shields.io/badge/renovate-enabled-1a1f6c?logo=renovate)](https://github.com/shatadru/homelab/blob/main/renovate.json)

## Architecture

```mermaid
graph TD
    G[Git Repository] --> A[Argo CD]
    A --> I[Infrastructure]
    A --> W[Workloads]

    subgraph K[Kubernetes Cluster]
        C[Cilium]
        LB[Load Balancer]
        T[Ingress]
        S[Services]
        P[Applications]
        C --> T
        LB --> T
        T --> S --> P
    end

    I --> K
    W --> P
    N[Network Storage] --> P
    D[Persistent Storage] --> P
    R[Remote Access] --> P
```

The platform uses **Argo CD** to reconcile desired state from Git. **Cilium** provides networking, policy, and observability, while an ingress layer exposes services. Persistent data is managed separately from application workloads.

## Stack

| Area | Technology |
| --- | --- |
| Kubernetes | K3s |
| Networking & Policy | Cilium · Hubble |
| GitOps | Argo CD |
| Ingress | Traefik · Kubernetes Ingress |
| Load Balancing | MetalLB |
| Remote Access | Tailscale Operator |
| TLS | cert-manager |
| Database | CloudNativePG |
| Observability | Prometheus · Grafana · Alertmanager |
| Uptime | Gatus |
| Automation | Ansible · Renovate · GitHub Actions |

## Repository Layout

```text
homelab/
├── ansible/       # automation
├── apps/          # Argo CD applications
├── bootstrap/     # cluster bootstrap
├── charts/        # Helm charts
├── clusters/      # GitOps configuration
└── docs/          # documentation
```

## GitOps

Infrastructure and workloads are defined declaratively and reconciled through Argo CD.

- Changes are reviewed through Git pull requests.
- Helm-based applications are managed from version-controlled configuration.
- Renovate keeps dependencies and chart versions up to date.
- GitHub Actions provides automated repository checks.

## Storage

Storage is treated independently from application deployment:

- Persistent storage for stateful workloads
- Network storage for shared or large data
- Application configuration remains declarative and version controlled

## Applications

The platform provides a consistent way to deploy and operate self-hosted applications with common networking, storage, security, and observability patterns.

> A practical homelab for learning, automation, reliability, and modern infrastructure practices.
