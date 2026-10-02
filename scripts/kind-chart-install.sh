#!/usr/bin/env bash
#
# Install a Kind-friendly subset of wrapper charts and wait until they are Ready.
# Skips charts that need NAS, Tailscale OAuth, Cilium host networking, or app secrets.
# Kind's default StorageClass is named standard. It uses a local-path
# provisioner, but the class name is not local-path, so that wrapper is
# not installed here.
#
# Usage:
#   ./scripts/kind-chart-install.sh
#   CREATE_CLUSTER=0 KUBECONFIG=/path/to/kind.kubeconfig ./scripts/kind-chart-install.sh
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHARTS_DIR="${CHARTS_DIR:-$REPO_ROOT/charts}"
CLUSTER_NAME="${CLUSTER_NAME:-homelab-ci}"
CREATE_CLUSTER="${CREATE_CLUSTER:-1}"
DELETE_CLUSTER="${DELETE_CLUSTER:-$CREATE_CLUSTER}"
HELM_TIMEOUT="${HELM_TIMEOUT:-15m}"
KIND_NODE_IMAGE="${KIND_NODE_IMAGE:-kindest/node:v1.31.2}"

# Prefer a real Helm binary. Some developer machines wrap `helm` in a pipe that
# always exits 0, which would hide install failures.
if [[ -z "${HELM_BIN:-}" ]]; then
  if command -v helm_actual >/dev/null 2>&1; then
    HELM_BIN=helm_actual
  else
    HELM_BIN=helm
  fi
fi

# chart_dir|release|namespace
CHARTS=(
  "cert-manager|cert-manager|cert-manager"
  "cnpg|cnpg|cnpg-system"
  "metallb|metallb|metallb-system"
  "traefik|traefik|traefik"
  "gatus|gatus|gatus"
  "argocd|argo-cd|argocd"
)

need_bin() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "error: '$1' not found on PATH" >&2
    exit 2
  }
}

need_bin "${HELM_BIN}"
need_bin kubectl

if ((CREATE_CLUSTER)); then
  need_bin kind
  need_bin docker
fi

assert_cluster_is_kind() {
  local context server
  context="$(kubectl config current-context 2>/dev/null || true)"
  server="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || true)"

  if [[ "${context}" != "kind-${CLUSTER_NAME}" ]]; then
    echo "error: refusing to install; current context is '${context}', expected 'kind-${CLUSTER_NAME}'" >&2
    exit 3
  fi
  if [[ "${server}" != https://127.0.0.1:* && "${server}" != https://localhost:* ]]; then
    echo "error: refusing to install; API server '${server}' does not look like a local Kind cluster" >&2
    exit 3
  fi
}

refresh_kind_kubeconfig() {
  if ((CREATE_CLUSTER)) && command -v kind >/dev/null 2>&1; then
    kind export kubeconfig --name "${CLUSTER_NAME}" --kubeconfig "${KUBECONFIG}"
  fi
  assert_cluster_is_kind
}

assert_deployed() {
  local chart_name="$1" namespace="$2"

  refresh_kind_kubeconfig

  local deploys=""
  if ! deploys="$(kubectl get deploy -n "${namespace}" -o name 2>&1)"; then
    echo "error: cannot list Deployments in namespace ${namespace}" >&2
    printf '%s\n' "${deploys}" >&2
    exit 1
  fi
  if [[ -z "${deploys}" ]]; then
    echo "== ${chart_name}: no Deployments to wait on =="
    return 0
  fi

  if ! kubectl wait --namespace "${namespace}" \
    --for=condition=Available \
    --timeout=300s \
    deployment --all; then
    echo "error: deployments not Available in namespace ${namespace}" >&2
    kubectl get pods -n "${namespace}" -o wide || true
    kubectl get events -n "${namespace}" --sort-by=.lastTimestamp | tail -30 || true
    exit 1
  fi
}

cleanup() {
  exit_code=$?
  if ((DELETE_CLUSTER)); then
    echo "== deleting kind cluster ${CLUSTER_NAME} =="
    kind delete cluster --name "${CLUSTER_NAME}" >/dev/null 2>&1 || true
  fi
  if [[ -n "${KUBECONFIG_TMP:-}" && -f "${KUBECONFIG_TMP}" ]]; then
    rm -f "${KUBECONFIG_TMP}"
  fi
  exit "${exit_code}"
}

create_cluster() {
  echo "== creating kind cluster ${CLUSTER_NAME} =="
  if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
    kind delete cluster --name "${CLUSTER_NAME}"
  fi
  kind create cluster \
    --name "${CLUSTER_NAME}" \
    --image "${KIND_NODE_IMAGE}" \
    --kubeconfig "${KUBECONFIG}"
  refresh_kind_kubeconfig
  kubectl cluster-info
}

register_repos() {
  local chart_dir="$1" url name
  while IFS= read -r url; do
    [[ -z "$url" ]] && continue
    [[ "$url" == oci://* ]] && continue
    name="auto-$(printf '%s' "$url" | md5sum | cut -c1-12)"
    # force-update refreshes this repo index only; avoid a full `helm repo update`
    # against every configured repo (slow and noisy on developer machines).
    if ! "${HELM_BIN}" repo add "$name" "$url" --force-update >/dev/null; then
      echo "error: helm repo add failed for ${url}" >&2
      exit 1
    fi
  done < <(grep -E '^[[:space:]]+repository:' "${chart_dir}/Chart.yaml" | awk '{print $2}' | tr -d '"')
}

helm_install() {
  local chart_dir="$1" release="$2" namespace="$3"
  local -a kubeconfig_args=()
  assert_cluster_is_kind
  if [[ -n "${KUBECONFIG:-}" ]]; then
    kubeconfig_args=(--kubeconfig "${KUBECONFIG}")
  fi
  "${HELM_BIN}" upgrade --install "${release}" "${chart_dir}" \
    --namespace "${namespace}" \
    --create-namespace \
    --values "${chart_dir}/values.yaml" \
    --values "${chart_dir}/ci/values.yaml" \
    --timeout "${HELM_TIMEOUT}" \
    --wait \
    "${kubeconfig_args[@]}"
}

install_chart() {
  local chart_name="$1" release="$2" namespace="$3"
  local chart_dir="${CHARTS_DIR}/${chart_name}"

  [[ -f "${chart_dir}/Chart.yaml" ]] || {
    echo "error: missing chart ${chart_dir}" >&2
    exit 2
  }
  [[ -f "${chart_dir}/ci/values.yaml" ]] || {
    echo "error: missing CI overlay ${chart_dir}/ci/values.yaml" >&2
    exit 2
  }

  echo "== ${chart_name}: dependency build =="
  register_repos "${chart_dir}"
  if ! "${HELM_BIN}" dependency build "${chart_dir}"; then
    echo "error: helm dependency build failed for ${chart_name}" >&2
    exit 1
  fi

  echo "== ${chart_name}: helm upgrade --install (${namespace}) =="
  if ! helm_install "${chart_dir}" "${release}" "${namespace}"; then
    echo "error: helm install failed for ${chart_name}" >&2
    kubectl get pods -n "${namespace}" -o wide || true
    kubectl get events -n "${namespace}" --sort-by=.lastTimestamp | tail -30 || true
    exit 1
  fi

  assert_deployed "${chart_name}" "${namespace}"
  echo "== ${chart_name}: ok =="
}

main() {
  echo "Using Helm binary: ${HELM_BIN} ($("${HELM_BIN}" version --short 2>/dev/null || true))"

  if ((DELETE_CLUSTER)) || ((CREATE_CLUSTER)); then
    trap cleanup EXIT
  fi

  if ((CREATE_CLUSTER)); then
    # Isolate from the developer's default kubeconfig so a context flip cannot
    # install charts into a shared/remote cluster.
    KUBECONFIG_TMP="$(mktemp)"
    export KUBECONFIG="${KUBECONFIG_TMP}"
    create_cluster
  else
    # Reuse the caller-provided kubeconfig. GitHub Actions must set KUBECONFIG
    # to the file written by kind-action. An empty value uses kubectl's default.
    assert_cluster_is_kind
  fi

  local entry chart_name release namespace
  for entry in "${CHARTS[@]}"; do
    IFS='|' read -r chart_name release namespace <<<"${entry}"
    install_chart "${chart_name}" "${release}" "${namespace}"
  done

  echo
  echo "Kind chart installs passed (${#CHARTS[@]} charts)."
}

main "$@"
