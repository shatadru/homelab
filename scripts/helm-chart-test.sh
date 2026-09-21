#!/usr/bin/env bash
#
# Basic Helm smoke tests for every wrapper chart in this repository.
#
# For each chart under charts/:
#   1. helm dependency build  - resolve the upstream subchart dependency
#   2. helm lint              - chart structure and metadata sanity
#   3. helm template          - everything renders (mirrors what Argo CD runs)
#
# Expandable by design: add a new check as a function, wire it up with an
# env flag, and it runs for every chart. Narrow the run to specific charts
# by passing chart names as positional arguments:
#
#   scripts/helm-chart-test.sh
#   scripts/helm-chart-test.sh argocd traefik
#   RUN_LINT=0 scripts/helm-chart-test.sh
#
# Usually invoked through tox so local and CI run the same checks:
#   tox                      # everything
#   tox -e helm-charts -- argocd   # just Helm checks for one chart
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHARTS_DIR="${CHARTS_DIR:-$REPO_ROOT/charts}"
NAMESPACE="${NAMESPACE:-default}"

# One flag per check; flip to 0 to skip a check.
RUN_DEP_BUILD="${RUN_DEP_BUILD:-1}"
RUN_LINT="${RUN_LINT:-1}"
RUN_TEMPLATE="${RUN_TEMPLATE:-1}"

failures=()

[[ -n "$(command -v helm)" ]] || {
  echo "error: helm CLI not found on PATH (install from https://helm.sh)" >&2
  exit 2
}

# ---------------------------------------------------------------------------
# Selection: all charts or only the ones passed as arguments.
# ---------------------------------------------------------------------------
list_charts() {
  local -a selected=("$@") charts=()
  if ((${#selected[@]})); then
    for name in "${selected[@]}"; do
      [[ -f "$CHARTS_DIR/$name/Chart.yaml" ]] || {
        echo "error: no chart named '$name' in $CHARTS_DIR" >&2
        exit 2
      }
      charts+=("$name")
    done
  else
    for chart_file in "$CHARTS_DIR"/*/Chart.yaml; do
      charts+=("$(basename "$(dirname "$chart_file")")")
    done
  fi
  printf '%s\n' "${charts[@]}"
}

# ---------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------
check_dep_build() {
  # Register upstream dependency repositories first so the build is
  # deterministic regardless of the machine's existing helm repo cache.
  local url name repo_err
  while IFS= read -r url; do
    [[ -z "$url" ]] && continue
    name="auto-$(printf '%s' "$url" | md5sum | cut -c1-12)"
    if ! repo_err="$(helm repo add "$name" "$url" 2>&1)"; then
      printf '  [repo] failed to register %s: %s\n' "$url" "$repo_err"
    fi
  done < <(grep -E '^[[:space:]]+repository:' "$1/Chart.yaml" | awk '{print $2}' | tr -d '"')

  if ! helm dependency build "$1" 2>&1; then
    printf '  [repo] hint: register the repository and retry, e.g.\n'
    printf '          helm repo add <name> <url> && helm dependency build %s\n' "$1"
    printf '          current repos: helm repo list\n'
    helm repo list 2>&1 | sed 's/^/          /'
    return 1
  fi
}

check_lint() {
  helm lint "$1"
}

check_template() {
  # Same rendering path Argo CD uses when generating manifests.
  helm template "$1" \
    --name-template "$(basename "$1")" \
    --namespace "$NAMESPACE" \
    --include-crds >/dev/null
}

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------
run_check() {
  local label="$1"
  shift
  local out
  if out="$("$@" 2>&1)"; then
    printf '  [OK] %s\n' "$label"
  else
    printf '  [FAIL] %s\n%s\n' "$label" "$out"
    failures+=("$label")
    return 1
  fi
}

main() {
  local chart chart_dir
  local count=0

  [[ -d "$CHARTS_DIR" ]] || {
    echo "error: charts directory not found: $CHARTS_DIR" >&2
    exit 2
  }

  printf 'helm %s | checks: dep-build=%s lint=%s template=%s | namespace=%s\n' \
    "$(helm version --short)" "$RUN_DEP_BUILD" "$RUN_LINT" "$RUN_TEMPLATE" "$NAMESPACE"

  while IFS= read -r chart; do
    chart_dir="$CHARTS_DIR/$chart"
    count=$((count + 1))
    echo "== $chart =="

    if ((RUN_DEP_BUILD)); then
      run_check "dependency build" check_dep_build "$chart_dir" || true
    fi
    if ((RUN_LINT)); then
      run_check "helm lint" check_lint "$chart_dir" || true
    fi
    if ((RUN_TEMPLATE)); then
      run_check "helm template" check_template "$chart_dir" || true
    fi
  done < <(list_charts "$@")

  ((count)) || { echo "error: no charts found in $CHARTS_DIR" >&2; exit 2; }

  if ((${#failures[@]})); then
    echo
    echo "FAILED ($count chart(s), ${#failures[@]} failing check(s)):"
    for f in "${failures[@]}"; do printf '  - %s\n' "$f"; done
    exit 1
  fi

  echo
  echo "All checks passed for $count chart(s)."
}

main "$@"
