# K3s Bootstrap

This directory contains the K3s server config and the first Cilium values.
Ansible cannot rebuild this host. `ansible/site.yml` calls roles `base`
and `k3s`, and those roles are not in the repository. Install K3s by hand, then
install Cilium, then follow `docs/bootstrap.md`.

## Configuration

- `config.yaml` — K3s server configuration
- `cilium-values.yaml` — Cilium Helm configuration

## Current platform

- K3s `v1.36.3+k3s1`
- Cilium `1.20.2`
- Initial node: `minisforum-server`
- Node IP: `192.168.0.163`

## Networking

- LAN: `192.168.0.0/24`
- Storage/NFS: `192.168.100.0/24`
- Pod CIDR: `10.42.0.0/16`
- Service CIDR: `10.43.0.0/16`

The dedicated NAS interface is not used for Kubernetes node networking.

## Automation

Applications are not bootstrapped by this layer. Once the base cluster is available, Argo CD manages infrastructure and workloads from Git. See `docs/bootstrap.md` for the install order.
