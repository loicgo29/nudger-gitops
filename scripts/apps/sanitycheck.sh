#!/usr/bin/env bash
set -euo pipefail

NS="ns-open4goods-recette"
APP="mysql-xwiki"

echo "🔎 Sanity check MySQL ($APP) dans le namespace $NS"

# 1. StatefulSet
echo "==> StatefulSet"
if ! kubectl -n $NS get sts $APP >/dev/null 2>&1; then
  echo "❌ StatefulSet $APP absent"
  exit 1
fi
kubectl -n $NS get sts $APP

# 2. Pod
echo "==> Pod"
kubectl -n $NS get pod -l app=$APP -o wide || true
POD=$(kubectl -n $NS get pod -l app=$APP -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -z "$POD" ]]; then
  echo "❌ Aucun pod trouvé"
  exit 1
fi
STATUS=$(kubectl -n $NS get pod "$POD" -o jsonpath='{.status.phase}')
if [[ "$STATUS" != "Running" ]]; then
  echo "⚠️ Pod $POD n’est pas Running (status=$STATUS)"
fi

# 3. PVC
echo "==> PVC"
PVC=$(kubectl -n $NS get pvc -l app=$APP -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -z "$PVC" ]]; then
  echo "⚠️ Aucun PVC trouvé"
else
  kubectl -n $NS get pvc "$PVC"
  kubectl -n $NS describe pvc "$PVC" | grep -E "Status:|StorageClass:|Capacity:"
fi

# 4. PV
if [[ -n "$PVC" ]]; then
  PV=$(kubectl get pv -o jsonpath="{.items[?(@.spec.claimRef.name=='$PVC')].metadata.name}" 2>/dev/null || echo "")
  if [[ -n "$PV" ]]; then
    kubectl get pv "$PV"
    kubectl describe pv "$PV" | grep -E "Status:|StorageClass:|Capacity:"
  else
    echo "⚠️ Aucun PV lié au PVC $PVC"
  fi
fi

# 5. Test connexion MySQL
if [[ "$STATUS" == "Running" ]]; then
  echo "==> Test connexion MySQL"
  PASS=$(kubectl -n $NS get secret ${APP}-secret -o jsonpath='{.data.MYSQL_ROOT_PASSWORD}' | base64 -d)
  if kubectl -n $NS exec -i "$POD" -- \
    mysql -u root -p"$PASS" -e "SELECT VERSION();" >/dev/null 2>&1; then
    echo "✅ Connexion MySQL OK"
  else
    echo "❌ Connexion MySQL échouée"
  fi
else
  echo "⚠️ Test MySQL ignoré car pod non Running"
fi
