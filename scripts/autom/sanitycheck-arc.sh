#!/bin/bash
set -euo pipefail

NS_ARC="actions-runner-system"
NS_RUNNER="ns-open4goods-recette"
RUNNER_DEPLOY="nudger-gitops-recette-runner"
REPO="loicgo29/nudger-gitops"

echo "=== [1] Vérification namespace ARC et pods ==="
kubectl get ns $NS_ARC --show-labels
kubectl -n $NS_ARC get pods -o wide

echo -e "\n=== [2] Vérification des CRDs ARC ==="
kubectl get crd | grep actions.summerwind.dev || echo "❌ CRDs ARC absents"

echo -e "\n=== [3] Vérification du secret GitHub App (scellé) ==="
kubectl -n $NS_ARC get secret actions-runner-controller -o yaml | grep github_app_id || echo "❌ Secret GitHub App manquant"

echo -e "\n=== [4] Vérification des webhooks ARC ==="
kubectl get mutatingwebhookconfigurations | grep actions-runner-controller || echo "⚠️ MutatingWebhook absent"
kubectl get validatingwebhookconfigurations | grep actions-runner-controller || echo "⚠️ ValidatingWebhook absent"

echo -e "\n=== [5] Vérification du déploiement ARC ==="
kubectl -n $NS_ARC rollout status deploy/actions-runner-controller || echo "❌ Le controller ARC n'est pas Ready"

echo -e "\n=== [6] Vérification du RunnerDeployment (recette) ==="
kubectl -n $NS_RUNNER get runnerdeployments -o wide

echo -e "\n=== [7] Vérification des RunnerReplicaSets (recette) ==="
kubectl -n $NS_RUNNER get runnerreplicasets -o wide

echo -e "\n=== [8] Vérification des Runners (recette) ==="
kubectl -n $NS_RUNNER get runners -o wide || echo "⚠️ Aucun runner trouvé"

echo -e "\n=== [9] Vérification des pods Runner (recette) ==="
kubectl -n $NS_RUNNER get pods -l actions-runner-controller/runner-deployment-name=$RUNNER_DEPLOY -o wide || echo "⚠️ Aucun pod runner trouvé"

echo -e "\n=== [10] Logs ARC pour erreurs récentes ==="
kubectl -n $NS_ARC logs deploy/actions-runner-controller -c manager --tail=100 | grep -iE "error|fail" || echo "✅ Pas d'erreurs ARC récentes"

echo -e "\n=== [11] Événements récents namespace recette ==="
kubectl -n $NS_RUNNER get events --sort-by=.metadata.creationTimestamp | tail -n 20
