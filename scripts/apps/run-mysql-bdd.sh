#!/bin/bash
set -euo pipefail

NS="ns-open4goods-recette"
APP="mysql-xwiki"
JOB_NAME="mysql-bdd"
YAML="$(git rev-parse --show-toplevel)/tests/bdd/yaml/job-mysql-bdd.yaml"

echo "🗑 Suppression du pod MySQL pour tester la persistance..."
kubectl -n "$NS" delete pod -l app=$APP --ignore-not-found
kubectl -n "$NS" wait pod -l app=$APP --for=condition=Ready --timeout=120s || true

echo "🚀 Lancement du job BDD..."
kubectl -n "$NS" delete job "$JOB_NAME" --ignore-not-found
kubectl -n "$NS" apply -f "$YAML"

echo "⏳ Attente que le pod du job démarre..."
while true; do
  POD=$(kubectl -n "$NS" get pods -l job-name=$JOB_NAME -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  [[ -n "$POD" ]] && break
  sleep 2
done
echo "📦 Pod: $POD"

echo "🔍 Attente de la fin du Job..."
kubectl -n "$NS" wait --for=condition=complete --timeout=180s job/$JOB_NAME || true

SUCCEEDED=$(kubectl -n "$NS" get job "$JOB_NAME" -o jsonpath='{.status.succeeded}')
FAILED=$(kubectl -n "$NS" get job "$JOB_NAME" -o jsonpath='{.status.failed}')

echo "📜 Logs du pod:"
kubectl -n "$NS" logs "$POD" || true

if [[ "$SUCCEEDED" == "1" ]]; then
  echo "✅ BDD test MySQL PASSED (persistance OK)"
  exit 0
elif [[ "$FAILED" == "1" ]]; then
  echo "❌ BDD test MySQL FAILED (persistance KO)"
  exit 1
else
  echo "⚠️ Job $JOB_NAME terminé avec statut indéterminé"
  exit 2
fi
