#!/bin/bash
set -euo pipefail

NS="ns-open4goods-recette"
JOB_NAME="xwiki-bdd"
YAML="tests/smoke-tests/xwiki/job-xwiki-bdd.yaml"

echo "🧹 Suppression de l’ancien Job (si existe)..."
kubectl -n "$NS" delete job "$JOB_NAME" --ignore-not-found

echo "🚀 Lancement du Job $JOB_NAME..."
kubectl -n "$NS" apply -f "$YAML"

echo "⏳ Attente de complétion..."
kubectl -n "$NS" wait --for=condition=complete --timeout=300s job/$JOB_NAME || true

POD=$(kubectl -n "$NS" get pods -l job-name=$JOB_NAME -o jsonpath='{.items[0].metadata.name}')
echo "📦 Pod: $POD"

echo "📜 Logs du pod:"
kubectl -n "$NS" logs "$POD" || true

STATUS=$(kubectl -n "$NS" get job "$JOB_NAME" -o jsonpath='{.status.succeeded}')
if [[ "$STATUS" == "1" ]]; then
  echo "✅ XWiki BDD test PASSED"
  exit 0
else
  echo "❌ XWiki BDD test FAILED"
  exit 1
fi
