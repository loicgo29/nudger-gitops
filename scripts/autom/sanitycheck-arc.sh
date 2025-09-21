#!/bin/bash
set -euo pipefail

NS_ARC="actions-runner-system"
NS_RUNNER="ns-open4goods-recette"
RUNNER_DEPLOY="nudger-gitops-recette-runner"
REPO="loicgo29/nudger-gitops"

echo "=== [1] Vérification du namespace ARC et des pods ==="
kubectl get ns $NS_ARC --show-labels || { echo "❌ Namespace $NS_ARC absent"; exit 1; }
kubectl -n $NS_ARC get pods -o wide

echo -e "\n=== [2] Vérification des CRDs ARC ==="
kubectl get crd | grep actions.summerwind.dev || { echo "❌ CRDs ARC absents"; exit 1; }

echo -e "\n=== [3] Vérification des secrets GitHub App ==="
kubectl -n $NS_ARC get secret actions-runner-controller -o yaml | grep github_app_id || {
  echo "❌ Secret GitHub App manquant"; exit 1;
}

echo -e "\n=== [4] Vérification des webhooks ARC ==="
kubectl get mutatingwebhookconfigurations | grep actions-runner-controller || echo "⚠️ MutatingWebhook absent"
kubectl get validatingwebhookconfigurations | grep actions-runner-controller || echo "⚠️ ValidatingWebhook absent"

echo -e "\n=== [5] Vérification du Deployment ARC ==="
kubectl -n $NS_ARC rollout status deploy/actions-runner-controller || {
  echo "❌ Le controller ARC n'est pas Ready"; exit 1;
}

echo -e "\n=== [6] Vérification du RunnerDeployment ==="
kubectl -n $NS_RUNNER get runnerdeployments $RUNNER_DEPLOY -o yaml | yq '.spec.template.spec' || {
  echo "❌ RunnerDeployment absent ou mal configuré"; exit 1;
}

echo -e "\n=== [7] Vérification des pods Runner ==="
kubectl -n $NS_RUNNER get pods -l actions-runner-controller/runner-deployment-name=$RUNNER_DEPLOY -o wide || echo "⚠️ Aucun pod runner trouvé"

echo -e "\n=== [8] Logs ARC pour erreurs récentes ==="
kubectl -n $NS_ARC logs deploy/actions-runner-controller -c manager --tail=50 | grep -iE "error|fail" || echo "✅ Pas d'erreurs ARC récentes"

echo -e "\n=== [9] Vérification GitHub API (optionnel) ==="
curl -s -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/$REPO/actions/runners | jq '.runners[] | {name, status, labels}'
echo -e "\n=== [7b] Événements récents namespace runner ==="
kubectl -n $NS_RUNNER get events --sort-by=.metadata.creationTimestamp | tail -n 20
