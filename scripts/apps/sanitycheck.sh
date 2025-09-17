#!/usr/bin/env bash
set -euo pipefail

NS="ns-open4goods-recette"
MYSQL_APP="mysql-xwiki"
XWIKI_APP="xwiki"

echo "🔎 Sanity check MySQL ($MYSQL_APP) et XWiki ($XWIKI_APP) dans le namespace $NS"

# 1. Vérifier le StatefulSet MySQL
echo "==> StatefulSet MySQL"
if ! kubectl -n $NS get sts $MYSQL_APP >/dev/null 2>&1; then
  echo "❌ StatefulSet $MYSQL_APP absent"
  exit 1
fi
kubectl -n $NS get sts $MYSQL_APP

# 2. Vérifier les Pods MySQL
echo "==> Pods MySQL"
kubectl -n $NS get pod -l app=$MYSQL_APP -o wide || true
MYSQL_POD=$(kubectl -n $NS get pod -l app=$MYSQL_APP -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -z "$MYSQL_POD" ]]; then
  echo "❌ Aucun pod MySQL trouvé"
  exit 1
fi
STATUS=$(kubectl -n $NS get pod "$MYSQL_POD" -o jsonpath='{.status.phase}')
if [[ "$STATUS" != "Running" ]]; then
  echo "⚠️ Pod MySQL $MYSQL_POD n’est pas Running (status=$STATUS)"
fi

# 3. Vérifier le PVC MySQL
echo "==> PVC MySQL"
PVC=$(kubectl -n $NS get pvc -l app=$MYSQL_APP -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -z "$PVC" ]]; then
  echo "⚠️ Aucun PVC MySQL trouvé"
else
  kubectl -n $NS get pvc "$PVC"
  kubectl -n $NS describe pvc "$PVC" | grep -E "Status:|StorageClass:|Capacity:"
fi

# 4. Vérifier les PVs liés aux PVC MySQL
PVC_LIST=$(kubectl -n $NS get pvc -o jsonpath='{.items[*].spec.volumeName}')

for pv in $PVC_LIST; do
  if [[ -n "$pv" ]]; then
    echo "==> PV $pv"
    kubectl get pv "$pv" 2>/dev/null || echo "⚠️ PV $pv introuvable (probablement supprimé)"
    kubectl describe pv "$pv" 2>/dev/null | grep -E "Status:|StorageClass:|Capacity:" || true
  else
    echo "⚠️ Aucun PV trouvé pour ce PVC"
  fi
done

# 5. Vérifier la connexion MySQL
if [[ "$STATUS" == "Running" ]]; then
  echo "==> Test connexion MySQL"
  PASS=$(kubectl -n $NS get secret ${MYSQL_APP}-secret -o jsonpath='{.data.password}' | base64 -d)
  if kubectl -n $NS exec -i "$MYSQL_POD" -- \
    mysql -u root -p"$PASS" -e "SELECT VERSION();" >/dev/null 2>&1; then
    echo "✅ Connexion MySQL OK"
  else
    echo "❌ Connexion MySQL échouée"
  fi
else
  echo "⚠️ Test MySQL ignoré car pod MySQL non Running"
fi

# 6. Vérifier le StatefulSet XWiki
echo "==> StatefulSet XWiki"
if ! kubectl -n $NS get sts $XWIKI_APP >/dev/null 2>&1; then
  echo "❌ StatefulSet $XWIKI_APP absent"
  exit 1
fi
kubectl -n $NS get sts $XWIKI_APP

# 7. Vérifier les Pods XWiki
echo "==> Pods XWiki"
kubectl -n $NS get pod -l app=$XWIKI_APP -o wide || true
XWIKI_POD=$(kubectl -n $NS get pod -l app=$XWIKI_APP -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -z "$XWIKI_POD" ]]; then
  echo "❌ Aucun pod XWiki trouvé"
  exit 1
fi
STATUS=$(kubectl -n $NS get pod "$XWIKI_POD" -o jsonpath='{.status.phase}')
if [[ "$STATUS" != "Running" ]]; then
  echo "⚠️ Pod XWiki $XWIKI_POD n’est pas Running (status=$STATUS)"
fi

# 8. Vérifier le PVC XWiki
echo "==> PVC XWiki"
PVC=$(kubectl -n $NS get pvc -l app=$XWIKI_APP -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -z "$PVC" ]]; then
  echo "⚠️ Aucun PVC XWiki trouvé"
else
  kubectl -n $NS get pvc "$PVC"
  kubectl -n $NS describe pvc "$PVC" | grep -E "Status:|StorageClass:|Capacity:"
fi

# 9. Vérifier la connexion à XWiki
if [[ "$STATUS" == "Running" ]]; then
  echo "==> Test connexion XWiki"
  if kubectl -n $NS exec -i "$XWIKI_POD" -- \
    curl -s http://localhost:8080/bin/view/Main/ >/dev/null; then
    echo "✅ Connexion XWiki OK"
  else
    echo "❌ Connexion XWiki échouée"
  fi
else
  echo "⚠️ Test XWiki ignoré car pod non Running"
fi
