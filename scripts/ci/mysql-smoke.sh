#!/usr/bin/env bash
set -euo pipefail

echo "🚀 MySQL smoke test démarré..."

# KUBECONFIG
if [[ -n "${KUBECONFIG_B64:-}" ]]; then
  echo "$KUBECONFIG_B64" | base64 -d > kubeconfig
  export KUBECONFIG=$PWD/kubeconfig
fi

# Vérif cluster
kubectl cluster-info

# Exécution via ton script maison
bash scripts/apps/run-mysql-smoke.sh
