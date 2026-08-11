#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="argocd"
RELEASE="argo-cd"
CHART="argo-cd/argo-cd"
VERSION="10.3.2"

helm upgrade --install "${RELEASE}" "${CHART}" \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  --version "${VERSION}" \
  --values "$(dirname "$0")/values.yaml" \
  --wait
