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

# Exécution du job de smoke-test (ajuste le chemin si nécessaire)
kubectl delete -f smoke-tests/yaml/job-mysql-smoke.yaml --ignore-not-found
kubectl apply -f smoke-tests/yaml/job-mysql-smoke.yaml

echo "⏳ Attente de la complétion du job..."
kubectl wait --for=condition=complete --timeout=120s job/mysql-smoke

echo "✅ Smoke test MySQL OK"
