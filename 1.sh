#!/usr/bin/env bash
set -euo pipefail

NS="ns-open4goods-recette"
POD_NAME="debug-runner-net"

echo "=== [1] Nettoyage ancien pod éventuel ==="
kubectl -n $NS delete pod $POD_NAME --ignore-not-found --grace-period=0 --force

echo
echo "=== [2] Lancement pod debug (image: curlimages/curl) ==="
kubectl -n $NS run $POD_NAME \
  --image=curlimages/curl:8.10.1 \
  --restart=Never \
  --command -- sleep 3600

echo
echo "=== [3] Attente que le pod soit Running ==="
kubectl -n $NS wait --for=condition=Ready pod/$POD_NAME --timeout=60s

echo
echo "=== [4] Test accès GitHub API ==="
kubectl -n $NS exec $POD_NAME -- curl -s -o /dev/null -w "%{http_code}\n" https://api.github.com
