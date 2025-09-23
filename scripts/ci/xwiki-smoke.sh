#!/bin/bash
set -euo pipefail

NS="ns-open4goods-recette"
JOB="xwiki-smoke-py"
YAML="tests/smoke-tests/xwiki/job-xwiki-smoke-py.yaml"

echo "🧹 Suppression de l’ancien job..."
kubectl -n "$NS" delete job "$JOB" --ignore-not-found

echo "🚀 Lancement du job $JOB..."
kubectl -n "$NS" apply -f "$YAML"

echo "⏳ Attente de complétion..."
kubectl -n "$NS" wait --for=condition=complete --timeout=180s job/$JOB || true

POD=$(kubectl -n "$NS" get pods -l job-name=$JOB -o jsonpath='{.items[0].metadata.name}')
echo "📦 Pod = $POD"
kubectl -n "$NS" logs "$POD" || true
