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

Tailscale ingress and Prometheus ServiceMonitors are still off in
`charts/argocd`. Workloads already live under `apps/workloads`.

## GitOps

After Argo CD is running, apply `clusters/production/infra.yaml` and
`clusters/production/workloads.yaml`. Those roots watch `apps/infra`
and `apps/workloads`. This directory does not register the Git repository
and does not install apps. The steps are in `docs/bootstrap.md`.

The Argo CD bootstrap itself remains separate from those applications
because it is required to establish the GitOps control plane.
