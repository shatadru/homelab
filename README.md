# HOMELAB

A self-hosted infrastructure platform built around Kubernetes, GitOps, and declarative configuration.

[![Super-Linter](https://github.com/shatadru/homelab/actions/workflows/super-linter.yml/badge.svg)](https://github.com/shatadru/homelab/actions/workflows/super-linter.yml)
[![Quality Checks](https://github.com/shatadru/homelab/actions/workflows/quality-checks.yml/badge.svg)](https://github.com/shatadru/homelab/actions/workflows/quality-checks.yml)
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

The platform uses **Argo CD** to reconcile desired state from Git. It uses App of App concepts to divide k8s workload in Infra Structure application and Workloads.

- **Cilium** provides networking
- **Cert-Manager** provides certs
- **Metal-LB** is for provisioning IP on baremetal
- Monitoring provided by **kube-prometheus-stack** which in turns provide *Prometheus*, *Grafana* and *Alert Manager*.
- **Gatus** provides synthetic uptime monitoring
- Traefik provides ingress controller for internal apps
- Persistent data is provided by **nfs-csi** connecting to a NAS box
- **Tailscale Operator** exposes services to internal tailnet
- **CNPG** provides cloudnative PostgreSQL operator to run Postgres DB
- The repository is connected and configured with Rennovate to propose PR to above charts.

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

## Local Checks

The same checks that CI runs can be executed locally with [tox](https://tox.wiki)
(Python 3.9+ and the [Helm CLI](https://helm.sh) installed):

```bash
pip install tox
tox                       # yamllint + helm-charts (dependency build, lint, template) for all charts
tox -e yamllint           # just YAML linting
tox -e helm-charts -- argocd  # just Helm checks, scoped to one chart
```

The `helm-charts` env validates every wrapper chart in `charts/`:

- `helm dependency build` — resolves the upstream subchart
- `helm lint` — chart structure and metadata sanity
- `helm template` — renders with the same flags Argo CD uses, so invalid
  YAML or bad values fail locally instead of at sync time

## Storage

Storage is treated independently from application deployment:

- Persistent storage for stateful workloads
- Network storage for shared or large data
- Application configuration remains declarative and version controlled

## Applications

The platform provides a consistent way to deploy and operate self-hosted applications with common networking, storage, security, and observability patterns.

> A practical homelab for learning, automation, reliability, and modern infrastructure practices.
