#!/usr/bin/env bash
# Regenerates spendwise-rendered.yaml: the plain Kubernetes manifests the Helm chart produces
# (for review, or for `kubectl apply` without Helm).
set -euo pipefail
cd "$(dirname "$0")/.."
helm template spendwise helm/spendwise -n spendwise -f helm/spendwise/values-local.yaml \
  > k8s/spendwise-rendered.yaml
echo "wrote k8s/spendwise-rendered.yaml"
