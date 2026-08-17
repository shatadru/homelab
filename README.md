# HOMELAB

Self-hosted infrastructure running on a Minisforum MS-A2, built around K3s, Cilium, Argo CD and GitOps.

[![Super-Linter](https://github.com/shatadru/homelab/actions/workflows/super-linter.yml/badge.svg)](https://github.com/shatadru/homelab/actions/workflows/super-linter.yml)

## Overview

The project is an incremental migration from Podman-hosted services to a small, GitOps-managed Kubernetes platform.

```text
Home LAN
   │
   ▼
MetalLB (LAN VIP)
   │
   ▼
Traefik
   │
   ▼
Kubernetes Ingress
   │
   ▼
Service → Pod
   │
   ▼
Cilium
```

For remote access, selected services can use Tailscale, while the existing Cloudflare/Tailscale path is retained for public services such as Immich.

## Stack

| Layer | Technology |
| --- | --- |
| Host | Minisforum MS-A2 / Fedora Linux |
| Kubernetes | K3s |
| Networking & Policy | Cilium + Hubble |
| GitOps | Argo CD |
| L7 Ingress | Traefik |
| Load Balancing | MetalLB |
| TLS | cert-manager |
| PostgreSQL | CloudNativePG |
| Monitoring | Prometheus / Grafana / Alertmanager |
| Uptime | Gatus |
| Remote Access | Tailscale Operator |
| Dashboard | Homarr |
| Automation | Ansible / Renovate / GitHub Actions |

## Repository

```text
homelab/
├── ansible/       # host and K3s automation
├── apps/          # Argo CD Applications
├── bootstrap/     # initial cluster/bootstrap configuration
├── charts/        # local Helm wrapper charts
├── clusters/      # cluster-level App-of-Apps definitions
└── docs/          # project documentation
```

The repository follows a simple GitOps model:

```text
clusters/production
        │
        ├── infra.yaml ──────► apps/infra
        │
        └── workloads.yaml ──► apps/workloads
```

`bootstrap/` is used for initial/recovery setup; steady-state infrastructure and workloads are managed through Argo CD.

## Current Workloads

Existing services are being migrated incrementally from Podman to Kubernetes.

- Immich
- Firecrawl
- SearXNG
- Hermes
- Open WebUI

Migration is deliberately conservative: existing state is inventoried and backed up before cutover, with the old deployment retained until the Kubernetes replacement is validated.

## Storage

The storage model is intentionally split by workload:

- **Local SSD** — databases and latency-sensitive state
- **Asustor NAS / NFS** — large durable media such as the Immich library

The current Kubernetes cluster is single-node, so node-local storage is accepted for now.

## CI & Automation

Repository hygiene and dependency maintenance are automated with:

- **GitHub Actions** — Super-Linter
- **Renovate** — Helm chart and Helm values updates
- **Ansible** — host/K3s bootstrap automation

Renovate PRs are created without automerge so infrastructure upgrades remain deliberate.

## Architecture

The current architecture is intentionally small and modular:

```text
                     GitHub
                        │
                        ▼
                     Argo CD
                  ┌─────┴─────┐
                  │           │
                Infra     Workloads
                  │           │
                  ▼           ▼
        Cilium / Traefik   Applications
        MetalLB / CNPG
        Monitoring / TLS
                  │
                  ▼
              K3s Cluster
                  │
        ┌─────────┴─────────┐
        ▼                   ▼
     Local SSD          Asustor NAS
                         (NFS)
```

## Status

The platform foundation is operational. Current focus is on storage readiness, network policies, ingress validation and safe workload migration.

> This is a personal homelab project focused on learning, automation, reliability and incremental infrastructure design.
