#!/bin/bash
set -euo pipefail

NS_RUNNER="ns-open4goods-recette"
SECRET_NAME="actions-runner-controller"
RUNNER_DEPLOY="nudger-gitops-recette-runner"
RUNNER_SET="nudger-gitops-recette-runnerset"
REPO="loicgo29/nudger-gitops"

echo "=== [1] Vérification du secret GitHub App dans $NS_RUNNER ==="
if kubectl -n $NS_RUNNER get secret $SECRET_NAME >/dev/null 2>&1; then
  echo "✅ Secret $SECRET_NAME trouvé dans $NS_RUNNER"
  echo "🔎 Variables présentes :"
  kubectl -n $NS_RUNNER get secret $SECRET_NAME -o json | jq -r '.data | keys'
else
  echo "❌ Secret $SECRET_NAME absent dans $NS_RUNNER"
fi

echo -e "\n=== [2] Vérification RunnerDeployment $RUNNER_DEPLOY ==="
kubectl -n $NS_RUNNER get runnerdeployment $RUNNER_DEPLOY 2>/dev/null || echo "ℹ️ Aucun RunnerDeployment (tu es probablement en RunnerSet)"

echo -e "\n=== [3] Vérification RunnerSet $RUNNER_SET ==="
kubectl -n $NS_RUNNER describe runnerset $RUNNER_SET || echo "❌ RunnerSet absent"

echo -e "\n=== [4] Vérification StatefulSets générés par RunnerSet ==="
kubectl -n $NS_RUNNER get statefulsets -l runnerset-name=$RUNNER_SET || echo "❌ Aucun StatefulSet trouvé"

echo -e "\n=== [5] Vérification RunnerReplicaSets ==="
kubectl -n $NS_RUNNER get runnerreplicasets || echo "ℹ️ Aucun RunnerReplicaSet (normal en RunnerSet)"

echo -e "\n=== [6] Vérification Runners ==="
kubectl -n $NS_RUNNER get runners -o wide || echo "❌ Aucun Runner trouvé"

echo -e "\n=== [7] Vérification Pods RunnerSet ==="
kubectl -n $NS_RUNNER get pods -l app=$RUNNER_SET -o wide || echo "❌ Aucun pod RunnerSet trouvé"

LATEST_RS_POD=$(kubectl -n $NS_RUNNER get pod \
  -l app=$RUNNER_SET \
  --sort-by=.metadata.creationTimestamp \
  -o jsonpath='{.items[-1].metadata.name}' 2>/dev/null || true)

if [[ -n "${LATEST_RS_POD:-}" ]]; then
  echo -e "\n👉 Pod RunnerSet sélectionné : $LATEST_RS_POD"

  echo -e "\n=== [8] Vérification fichier .runner (registre GitHub) ==="
  kubectl -n $NS_RUNNER exec "$LATEST_RS_POD" -c runner -- cat /runner/.runner 2>/dev/null || echo "⚠️ Fichier .runner introuvable"

  echo -e "\n=== [9] Vérification des variables d'env GitHub ==="
  kubectl -n $NS_RUNNER exec "$LATEST_RS_POD" -c runner -- env | grep GITHUB || echo "⚠️ Variables GitHub absentes"

  echo -e "\n=== [10] Logs du container runner ==="
  kubectl -n $NS_RUNNER logs "$LATEST_RS_POD" -c runner --tail=30 || echo "⚠️ Pas de logs runner"

  echo -e "\n=== [11] Logs du container docker ==="
  kubectl -n $NS_RUNNER logs "$LATEST_RS_POD" -c docker --tail=30 || echo "⚠️ Pas de logs docker"
else
  echo "⚠️ Aucun pod RunnerSet trouvé"
fi

echo -e "\n=== [12] Vérification GitHub API ==="
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  curl -s -H "Authorization: token $GITHUB_TOKEN" \
    https://api.github.com/repos/$REPO/actions/runners \
    | jq '.runners[] | {name,status,labels}' || echo "⚠️ Impossible d’interroger GitHub API"
else
  echo "⚠️ GITHUB_TOKEN non défini"
fi

echo -e "\n=== [13] Derniers événements namespace $NS_RUNNER ==="
kubectl -n $NS_RUNNER get events --sort-by=.metadata.creationTimestamp | tail -n 20

echo -e "\n=== [14] Logs du controller ARC (filtrés sur $NS_RUNNER) ==="
kubectl -n actions-runner-system logs deploy/actions-runner-controller -c manager --tail=20 | grep "$NS_RUNNER" || echo "⚠️ Aucun log ARC pour $NS_RUNNER"

echo -e "\n=== [15] SanityCheck Ingress ARC ==="
ING_NS="actions-runner-system"
ING_NAME="arc-webhook"
SVC_NAME="actions-runner-controller-webhook"

if kubectl -n $ING_NS get ingress $ING_NAME >/dev/null 2>&1; then
  echo "✅ Ingress $ING_NAME trouvé"
  kubectl -n $ING_NS get ingress $ING_NAME -o wide

  # Récupérer le port backend déclaré dans l’ingress
  BACKEND_PORT=$(kubectl -n $ING_NS get ingress $ING_NAME -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}')
  echo "🔎 Ingress pointe vers le port: $BACKEND_PORT"

  # Vérifier les ports réellement exposés par le Service
  echo "📡 Ports exposés par le Service $SVC_NAME:"
  kubectl -n $ING_NS get svc $SVC_NAME -o jsonpath='{.spec.ports[*].port}{"\n"}'

  if kubectl -n $ING_NS get svc $SVC_NAME >/dev/null 2>&1; then
    if kubectl -n $ING_NS get svc $SVC_NAME -o jsonpath="{.spec.ports[?(@.port==$BACKEND_PORT)].port}" | grep -q "$BACKEND_PORT"; then
      echo "✅ L’Ingress pointe sur un port valide du Service"
    else
      echo "❌ Mismatch: l’Ingress pointe sur $BACKEND_PORT mais le Service n’expose pas ce port"
    fi
  else
    echo "❌ Service $SVC_NAME introuvable"
  fi
else
  echo "❌ Ingress $ING_NAME absent"
fi
