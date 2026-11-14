# AGENTS.md

Guidance for human and AI agents working in this repository. This is a
GitOps homelab: the desired state of a single K3s cluster lives here, and
ArgO CD syncs `main` into the cluster. **You change the cluster by merging a
pull request**, not by running `kubectl apply` against manifests in this repo.

## Repository layout

```text
homelab/
├── ansible/       # Future host bootstrap (NOT complete yet / unused)
├── apps/          # Argo CD Application manifests  (app-of-apps split between infra and workloads)
│   ├── infra/     #   Shared platform: cilium, traefik, metallb, cert-manager, cnpg, monitoring...
│   └── workloads/ #   User services: immich, paperless-ngx, homarr, opencloud, labforge
├── bootstrap/     # One-time K3s + Argo CD install (argocd/, k3s/)
├── charts/        # Helm "wrapper" charts — what Argo actually deploys
├── clusters/      # Root app-of-apps entry points (production/{infra,workloads}.yaml)
├── docs/          # Human guides; the source of truth for how pieces work
├── scripts/       # Local + CI test helpers (helm-chart-test.sh, kind-chart-install.sh)
├── skills/        # Reusable agent skill markdown (k8s troubleshoot / gather-omc)
├── .github/       # CI workflows
├── renovate.json
├── tox.ini        # yamllint + helm-charts test envs
└── .yamllint.yml  # YAML lint config (repo convention)
```

## How an app gets on the cluster (mental model)

```
PR → Git main → Argo CD → clusters/production/{infra,workloads}.yaml
   → apps/{infra,workloads}/*.yaml (Argo Application)
   → charts/<app>/ (Helm wrapper) → K3s cluster
```

1. **`clusters/production/workloads.yaml`** and **`infra.yaml`** are the root
   "app of apps": an Argo Application pointing at `apps/workloads` (recurse)
   and `apps/infra` respectively.
2. Each **`apps/<group>/<app>.yaml`** is an Argo CD `Application` that points
   at this repo, a chart path under `charts/<app>`, and a target namespace.
3. **`charts/<app>/`** is a Helm wrapper chart. It depends on the upstream chart
   (often OCI) and layers in custom `values.yaml` plus repo-owned templates
   (e.g. CNPG `Cluster`, PVs/PVCs, StorageClasses, Ingress templates).
4. Argo CD performs the sync. Auto-sync + `selfHeal` + `prune` (+ `ServerSideApply`
   and `CreateNamespace` sync options) are the norm.

## Where things live

### Infrastructure (`apps/infra`) — shared platform

Argo CD(argo-cd), CNI/network policy(Cilium, `kube-system`), cert-manager,
MetalLB (`metallb-system`), Traefik ingress (`traefik`), local-path storage,
nfs-csi (NAS, StorageClass `nas-nfs`), CNPG Postgres operator (`cnpg-system`),
monitoring-stack (Prometheus/Grafana/Alertmanager, `monitoring`), gatus uptime,
adguard-home (LAN DNS), tailscale-operator, and Gateway API CRDs (upstream repo).

### Workloads (`apps/workloads`) — user services

| App | Chart | Namespace | Notes |
| --- | --- | --- | --- |
| immich | `charts/immich` | `immich` | Photos. CNPG + static NFS library volume |
| paperless-ngx | `charts/paperless-ngx` | `paperless-ngx` | Documents. CNPG + nas-nfs |
| homarr | `charts/homarr` | `homarr` | Dashboard. sqlite on local-path |
| opencloud | `charts/opencloud` | `opencloud` | Files. nas-nfs data, local-path state |
| labforge | `charts/labforge` | `labforge` | KVM lab control plane. Pocket ID + oauth2-proxy, ntfy |

## Critical gotchas (read before changing or debugging)

- **Secrets are NOT in Git.** Read `docs/secrets-and-storage.md`. Many apps
  need out-of-band `Secret` objects (e.g. `immich-db-credentials`) and a
  ClusterIssuer named `homelab-selfsigned`. A workload stuck `Pending` or
  `CrashLooping` is often a missing Secret/PVC/cert, not a chart bug. Never
  put passwords into `values.yaml`.
- **`local-path` and `nas-nfs` are NOT the default StorageClass.** A PVC with
  no class stays `Pending`. K3s local-storage is disabled
  (`bootstrap/k3s/config.yaml`).
- **Storage cutover is one-way.** Changing a PVC's `storageClassName` does not
  move or resize existing data. Deleting a `local-path` claim deletes the node
  data. NFS volume deletion does not delete the NAS export.
- **NFS flavors differ on purpose.** Immich PV uses NFSv3; `nas-nfs` uses
  nfsvers=4.2. OpenCloud expects NFSv4.2-style behavior. Don't unify them.
- **Repos are OpenCode / GitOps artifacts.** e.g. `apps/*.yaml` references
  `git@github.com:shatadru/homelab.git`. Keep the repoURL and repo layout
  consistent.

## Local checks / CI

The same checks CI runs. Requires the **Helm CLI on `PATH`**:

```bash
pip install tox
tox                       # yamllint + helm-charts
tox -e yamllint
tox -e helm-charts -- argocd
```

Kind install tests (needs Docker, Kind, kubectl, Helm):

```bash
tox -e kind-charts
# or
./scripts/kind-chart-install.sh
```

Conventions enforced by `.yamllint.yml`:
- No leading `---` document marker (most files omit it).
- `line-length` max 160 (warning level).
- `on:` allowed as a mapping key in GitHub Actions.
- Ignores: `.git/`, `charts/*/charts/`, `charts/*/templates/`.

`.gitignore` notes: `charts/*/charts/` (Helm deps rebuilt by `helm dependency
build`) is ignored, while `Chart.lock` stays in Git so checks verify a digest;
`nfs-csi` and `paperless-ngx` re-include their `charts/` dir.

## Good first questions when adding/changing an app

- Should it be infrastructure or a workload? (Shared platform vs. user service.)
- Is the external Secret documented in `docs/secrets-and-storage.md`?
- Does it need storage? Which StorageClass (`local-path` vs `nas-nfs` vs a
  static PV) and does the NAS export exist?
- Does it need a CNPG Postgres `Cluster` and matching `*-db-credentials`?
- Confirm the wrapper chart depends on the correct upstream version and runs
  `helm dependency build` (Chart.lock regenerated/checked).

## When in doubt

Read `docs/`, starting with `docs/README.md`, then `architecture.md`,
`gitops.md`, `applications.md`, and `secrets-and-storage.md`. These are the
authoritative human guides and stay more current than this file.