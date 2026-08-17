# HOMELAB

Self-hosted infrastructure on a **Minisforum MS-A2**, evolving from Podman workloads into a small, GitOps-managed Kubernetes platform.

[![Super-Linter](https://github.com/shatadru/homelab/actions/workflows/super-linter.yml/badge.svg)](https://github.com/shatadru/homelab/actions/workflows/super-linter.yml)
[![Renovate](https://img.shields.io/badge/renovate-enabled-1a1f6c?logo=renovate)](https://github.com/shatadru/homelab/blob/main/renovate.json)

## Architecture

```mermaid
graph TD
    G[GitHub] --> A[Argo CD]
    A --> I[Infrastructure]
    A --> W[Workloads]

    subgraph K[K3s — single node]
        C[Cilium]
        GW[Gateway API / Ingress]
        P[Platform Services]
        C --> GW
        GW --> P
        GW --> W
    end

    I --> K

    T[Tailscale] --> GW
    L[Home LAN] --> GW
    N[Asustor NAS / NFS] --> W
    S[Local SSD] --> P

    X[Existing Podman Workloads] -. migration .-> W
```

The platform uses **Cilium** for networking and policy, **Argo CD** for GitOps, and **Tailscale** for selected remote access. Public services such as Immich retain the existing Cloudflare/Tailscale path while migration is in progress.

## Stack

| Area | Technology |
| --- | --- |
| Host | Minisforum MS-A2 · Fedora Linux |
| Kubernetes | K3s |
| Networking | Cilium · Hubble |
| GitOps | Argo CD |
| Ingress | Gateway API · Cilium |
| Remote access | Tailscale Operator |
| TLS | cert-manager |
| Database | CloudNativePG |
| Observability | Prometheus · Grafana · Alertmanager |
| Uptime | Gatus |
| Automation | Ansible · Renovate · GitHub Actions |

## Repository Layout

```text
homelab/
├── ansible/       # host and K3s automation
├── apps/          # Argo CD applications
├── bootstrap/     # initial/recovery configuration
├── charts/        # local Helm charts
├── clusters/      # cluster-level GitOps configuration
└── docs/          # documentation
```

`bootstrap/` establishes the base platform. `apps/` and `clusters/` define the desired runtime state managed by Argo CD.

## Workloads

The current migration includes:

- Immich
- Firecrawl
- SearXNG
- Hermes
- Open WebUI

Stateful workloads are migrated incrementally with backup, validation and rollback in mind. Existing Podman services remain in place until their Kubernetes replacements are proven.

## Storage

- **Local SSD** — PostgreSQL, Redis and latency-sensitive state
- **Asustor NAS / NFS** — durable shared data and large media such as the Immich library

The cluster is intentionally **single-node** for now.

## CI & Dependency Management

- **GitHub Actions** runs Super-Linter.
- **Renovate** tracks Helm charts and Helm values.
- Dependency updates are opened as PRs rather than automatically merged.

## Status

The Kubernetes foundation is operational. Current work is focused on Gateway API validation, storage readiness, network policies and safe workload migration.

> Personal homelab focused on learning, automation, reliability and pragmatic infrastructure design.
