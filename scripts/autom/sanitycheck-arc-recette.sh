#!/bin/bash
set -euo pipefail

NS_RUNNER="ns-open4goods-recette"
SECRET_NAME="actions-runner-controller"
RUNNER_DEPLOY="nudger-gitops-recette-runner"
REPO="loicgo29/nudger-gitops"

echo "=== [1] Vérification du secret GitHub App dans $NS_RUNNER ==="
if kubectl -n $NS_RUNNER get secret $SECRET_NAME >/dev/null 2>&1; then
  echo "✅ Secret $SECRET_NAME trouvé dans $NS_RUNNER"
else
  echo "⚠️ Secret $SECRET_NAME absent dans $NS_RUNNER (il est peut-être uniquement dans actions-runner-system)"
fi

echo -e "\n=== [2] Vérification RunnerDeployment $RUNNER_DEPLOY ==="
if kubectl -n $NS_RUNNER get runnerdeployment $RUNNER_DEPLOY >/dev/null 2>&1; then
  kubectl -n $NS_RUNNER describe runnerdeployment $RUNNER_DEPLOY | grep -A10 "Spec:"
else
  echo "❌ RunnerDeployment $RUNNER_DEPLOY manquant"
fi

echo -e "\n=== [3] Vérification RunnerReplicaSets ==="
kubectl -n $NS_RUNNER get runnerreplicasets || echo "❌ Aucun RunnerReplicaSet trouvé"

echo -e "\n=== [4] Vérification Runners ==="
kubectl -n $NS_RUNNER get runners -o wide || echo "❌ Aucun Runner trouvé"

echo -e "\n=== [5] Vérification des pods Runner ==="
kubectl -n $NS_RUNNER get pods -l runner-deployment-name=$RUNNER_DEPLOY -o wide || echo "❌ Aucun pod Runner trouvé"

echo -e "\n=== [6] Logs d'un Runner récent (s'il existe) ==="
LATEST_POD=$(kubectl -n $NS_RUNNER get pod \
  -l runner-deployment-name=$RUNNER_DEPLOY \
  --sort-by=.metadata.creationTimestamp \
  -o jsonpath='{.items[-1].metadata.name}' 2>/dev/null || true)

if [[ -n "${LATEST_POD:-}" ]]; then
  echo "👉 Pod sélectionné : $LATEST_POD"
  kubectl -n $NS_RUNNER logs "$LATEST_POD" -c runner --tail=30 || echo "⚠️ Pas de logs récupérés"
else
  echo "⚠️ Aucun pod Runner trouvé"
fi

echo -e "\n=== [7] Vérification GitHub API ==="
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  curl -s -H "Authorization: token $GITHUB_TOKEN" \
    https://api.github.com/repos/$REPO/actions/runners \
    | jq '.runners[] | {name,status,labels}' || echo "⚠️ Impossible d'interroger l'API GitHub"
else
  echo "⚠️ GITHUB_TOKEN non défini, saute la vérif API"
fi

echo -e "\n=== [8] Événements récents ==="
kubectl -n $NS_RUNNER get events --sort-by=.metadata.creationTimestamp | tail -n 20
