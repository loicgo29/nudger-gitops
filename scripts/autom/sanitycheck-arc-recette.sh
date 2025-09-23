#!/usr/bin/env bash
set -euo pipefail

NS="ns-open4goods-recette"
APP="nudger-gitops-recette-runner"

echo "=== [1] Vérification du secret GitHub App dans $NS ==="
if kubectl -n "$NS" get secret actions-runner-controller &>/dev/null; then
  echo "✅ Secret trouvé"
else
  echo "❌ Secret manquant"
  exit 1
fi

echo -e "\n=== [2] Vérification RunnerDeployment $APP ==="
if kubectl -n "$NS" get runnerdeployment "$APP" &>/dev/null; then
  echo "✅ RunnerDeployment présent"
else
  echo "❌ RunnerDeployment manquant"
  exit 1
fi

echo -e "\n=== [3] Vérification Pods ==="
kubectl -n "$NS" get pods -l runner-deployment-name=$APP -o wide || true

echo -e "\n=== [4] Logs du runner (tail -50) ==="
kubectl -n "$NS" logs -l runner-deployment-name=$APP -c runner --tail=50 || true

echo -e "\n=== [5] Logs du docker:dind (tail -20) ==="
kubectl -n "$NS" logs -l runner-deployment-name=$APP -c docker --tail=20 || true

echo -e "\n=== [6] Events namespace $NS (dernier 1m) ==="
kubectl -n "$NS" get events --sort-by=.metadata.creationTimestamp --field-selector type=Warning | tail -n 20
