#!/bin/bash
set -euo pipefail
NS="ns-open4goods-recette"
APP="mysql-xwiki"

echo "🗑 Suppression du Pod MySQL..."
kubectl -n $NS delete pod -l app=$APP --ignore-not-found

echo "⏳ Attente que le Pod revienne Ready..."
kubectl -n $NS wait pod -l app=$APP --for=condition=Ready --timeout=180s
