#!/bin/bash
set -euo pipefail

NS="ns-open4goods-recette"
JOB="xwiki-smoke"
YAML="tests/smoke-tests/xwiki/job-xwiki-smoke.yaml"

echo "🧹 Suppression du job précédent..."
kubectl -n "$NS" delete job "$JOB" --ignore-not-found

echo "🚀 Lancement du job $JOB..."
kubectl -n "$NS" apply -f "$YAML"

echo "⏳ Attente de complétion..."
kubectl -n "$NS" wait --for=condition=complete --timeout=120s job/$JOB || true

POD=$(kubectl -n "$NS" get pods -l job-name=$JOB -o jsonpath='{.items[0].metadata.name}')
echo "📦 Pod = $POD"
kubectl -n "$NS" logs "$POD" || true

STATUS=$(kubectl -n "$NS" get job "$JOB" -o jsonpath='{.status.succeeded}' 2>/dev/null || echo 0)

if [[ "$STATUS" == "1" ]]; then
  echo "✅ Smoke test XWiki PASSED"
  exit 0
else
  echo "❌ Smoke test XWiki FAILED"
  exit 1
fi
