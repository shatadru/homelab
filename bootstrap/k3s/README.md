# K3s Bootstrap

This directory contains configuration consumed by the K3s bootstrap automation.

The initial K3s cluster was established manually to validate the architecture.
The reproducible bootstrap is being implemented incrementally in `ansible/`.

## Configuration

- `config.yaml` — K3s server configuration
- `cilium-values.yaml` — Cilium Helm configuration

## Current platform

- K3s `v1.36.3+k3s1`
- Cilium `1.20.0`
- Initial node: `minisforum-server`
- Node IP: `192.168.0.163`

## Networking

- LAN: `192.168.0.0/24`
- Storage/NFS: `192.168.100.0/24`
- Pod CIDR: `10.42.0.0/16`
- Service CIDR: `10.43.0.0/16`

The dedicated NAS interface is not used for Kubernetes node networking.

## Automation

Ansible will become the authoritative mechanism for rebuilding the host and K3s bootstrap once the currently manual procedure has been converted and validated.

Applications are not bootstrapped by this layer. Once the base cluster is available, Argo CD manages infrastructure and workloads from Git.
