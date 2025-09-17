#!/bin/bash
set -euo pipefail

NS="ns-open4goods-recette"
JOB_NAME="mysql-smoke"
YAML="smoke-tests/yaml/job-mysql-smoke.yaml"

echo "🧹 Suppression de l’ancien Job s’il existe..."
kubectl -n "$NS" delete job "$JOB_NAME" --ignore-not-found

echo "🚀 Lancement du Job $JOB_NAME..."
kubectl -n "$NS" apply -f "$YAML"

echo "⏳ Attente que le pod du job démarre..."
for i in {1..60}; do
  POD=$(kubectl -n "$NS" get pods -l job-name=$JOB_NAME -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [[ -n "${POD:-}" ]]; then
    STATUS=$(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.status.phase}')
    if [[ "$STATUS" != "Pending" && "$STATUS" != "ContainerCreating" ]]; then
      break
    fi
  fi
  sleep 2
done

echo "📦 Pod: ${POD:-N/A} (status=${STATUS:-Unknown})"

echo "🔍 Attente de la fin du Job..."
kubectl -n "$NS" wait --for=condition=complete --timeout=180s job/$JOB_NAME || true

SUCCEEDED=$(kubectl -n "$NS" get job "$JOB_NAME" -o jsonpath='{.status.succeeded}' 2>/dev/null || echo 0)
FAILED=$(kubectl -n "$NS" get job "$JOB_NAME" -o jsonpath='{.status.failed}' 2>/dev/null || echo 0)

echo "📜 Logs du pod:"
kubectl -n "$NS" logs "$POD" || true

if [[ "$SUCCEEDED" == "1" ]]; then
  echo "✅ Smoke test MySQL PASSED"
  CLEANUP=1
  exit 0
elif [[ "$FAILED" == "1" ]]; then
  echo "❌ Smoke test MySQL FAILED"
  CLEANUP=1
  exit 1
else
  echo "⚠️ Job $JOB_NAME terminé avec statut indéterminé"
  CLEANUP=1
  exit 2
fi

# Nettoyage optionnel (décommente si tu veux supprimer après exécution)
#if [[ "$CLEANUP" == "1" ]]; then
#  echo "🧹 Nettoyage du Job $JOB_NAME..."
#  kubectl -n "$NS" delete job "$JOB_NAME" --ignore-not-found
#fi
