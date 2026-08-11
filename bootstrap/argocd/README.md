# Argo CD Bootstrap

This directory contains the minimal configuration required to bootstrap
Argo CD onto the K3s cluster.

Argo CD is the bootstrap dependency for the GitOps layer.

## Installation

The bootstrap uses the Argo CD Helm chart with a pinned chart version.

Run:

    ./bootstrap/argocd/install.sh

The script expects the `argo-cd` Helm repository to be configured.

    helm repo add argo-cd https://argoproj.github.io/argo-helm
    helm repo update

## Current version

- Helm chart: `10.3.2`
- Argo CD: `v3.5.0`

## Bootstrap configuration

`values.yaml` contains the minimal initial configuration.

The following are intentionally not configured yet:

- Tailscale ingress
- Prometheus ServiceMonitors
- Application workloads

Those will be introduced through the GitOps-managed infrastructure layer.

## GitOps

After Argo CD is running, the repository will be organized around two
primary GitOps entry points:

    apps/
    ├── infra/
    └── workloads/

Infrastructure and workload deployment will be managed declaratively
through Argo CD.

The Argo CD bootstrap itself remains separate from those applications
because it is required to establish the GitOps control plane.
