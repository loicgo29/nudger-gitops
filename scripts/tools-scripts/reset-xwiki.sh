#!/usr/bin/env bash
set -euo pipefail

NS="ns-open4goods-integration"
MYSQL_PVC="data-mysql-xwiki-0"
XWIKI_PVC="xwiki-data-xwiki-0"

echo "🗑 Suppression des finalizers sur les PVC..."
for pvc in "$MYSQL_PVC" "$XWIKI_PVC"; do
  if kubectl -n "$NS" get pvc "$pvc" &>/dev/null; then
	kubectl -n "$NS" patch pvc "$pvc" \
  --type=json \
  -p='[{"op":"remove","path":"/metadata/finalizers"}]'
  fi
done

echo "🗑 Suppression des PVC et Pods XWiki/MySQL..."
kubectl -n "$NS" delete pvc "$MYSQL_PVC" "$XWIKI_PVC" --ignore-not-found
kubectl -n "$NS" delete pod mysql-xwiki-0 xwiki-0 --ignore-not-found

echo "⏳ Attente que MySQL soit Ready..."
kubectl -n "$NS" wait --for=condition=ready pod -l app.kubernetes.io/name=mysql --timeout=300s

echo "🔑 Application des privilèges MySQL..."
export MYSQL_ROOT_PASSWORD=$(kubectl -n "$NS" get secret mysql-xwiki -o jsonpath='{.data.mysql-root-password}' | base64 -d)

kubectl -n "$NS" exec -i mysql-xwiki-0 -- \
  mysql -uroot -p"$MYSQL_ROOT_PASSWORD" <<'EOF'
DROP USER IF EXISTS 'xwiki'@'%';
CREATE USER 'xwiki'@'%' IDENTIFIED BY 'xwikiPass123!';
GRANT ALL PRIVILEGES ON *.* TO 'xwiki'@'%' WITH GRANT OPTION;
GRANT PROCESS, SUPER, RELOAD, EVENT, TRIGGER ON *.* TO 'xwiki'@'%';
FLUSH PRIVILEGES;
EOF

echo "⏳ Attente que XWiki soit Ready..."
kubectl -n "$NS" wait --for=condition=ready pod -l app=xwiki --timeout=600s

NODE_IP="${NODE_IP:-91.98.16.184}"
HOST="xwiki.integration.nudger.logo-solutions.fr"

echo "🌐 Test HTTP sur http://${NODE_IP}/bin/view/Main/ avec Host=${HOST} ..."
curl -vk -H "Host: ${HOST}" "http://${NODE_IP}/bin/view/Main/" || true

echo "✅ Reset terminé. Vérifie que la page XWiki s'affiche correctement."
