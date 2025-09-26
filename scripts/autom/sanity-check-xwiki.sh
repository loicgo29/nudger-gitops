#!/usr/bin/env bash
set -euo pipefail

# --- Namespaces ciblés --------------------------------------------------------
NAMESPACES=("ns-open4goods-integration" "ns-open4goods-recette")

echo "🔎 Sanity check XWiki + MariaDB for namespaces: ${NAMESPACES[*]}"
echo "----------------------------------------------------"

for ns in "${NAMESPACES[@]}"; do
  echo "🟢 Checking namespace: $ns"
  echo "----------------------------------------------------"

  # 1️⃣ Vérifier HelmRelease XWiki
  echo "1️⃣ HelmRelease XWiki:"
  kubectl -n "$ns" get helmrelease xwiki || echo "❌ HelmRelease xwiki not found"
  echo

  # 2️⃣ Vérifier StatefulSets
  echo "2️⃣ StatefulSets:"
  kubectl -n "$ns" get statefulset | grep -E "xwiki|mariadb" || echo "❌ No xwiki/mariadb statefulset found"
  echo

  # 3️⃣ Vérifier Pods
  echo "3️⃣ Pods:"
  kubectl -n "$ns" get pods -o wide | grep -E "xwiki|mariadb" || echo "❌ No xwiki/mariadb pods running"
  echo

  # 4️⃣ Vérifier PVC
  echo "4️⃣ PVC:"
  kubectl -n "$ns" get pvc | grep -E "xwiki" || echo "❌ No xwiki PVCs found"
  echo

  # 5️⃣ Vérifier le ConfigMap et Secret XWiki
  echo "5️⃣ ConfigMap / Secret XWiki:"
  kubectl -n "$ns" get cm xwiki -o yaml | grep -E "DB_" || echo "❌ ConfigMap xwiki missing"
  kubectl -n "$ns" get secret xwiki -o yaml | grep DB_PASSWORD || echo "❌ Secret xwiki missing"
  echo

  # 6️⃣ Tester connexion DB (MariaDB)
  echo "6️⃣ Database connectivity test:"
  DBPASS=$(kubectl -n "$ns" get secret xwiki -o jsonpath='{.data.DB_PASSWORD}' | base64 -d)
  if kubectl -n "$ns" exec -i xwiki-mariadb-0 -- mariadb -uxwiki -p"$DBPASS" xwiki -e "SELECT 1;" >/dev/null 2>&1; then
    echo "✅ MariaDB accessible with xwiki credentials"
  else
    echo "❌ MariaDB connection failed"
  fi
  echo

  # 7️⃣ Vérifier endpoint XWiki HTTP
  echo "7️⃣ XWiki HTTP check:"
  XWIKI_HOST=$(kubectl -n "$ns" get ingress xwiki -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || echo "none")
  if [[ "$XWIKI_HOST" != "none" ]]; then
    if curl -s -o /dev/null -w "%{http_code}" "http://$XWIKI_HOST" | grep -qE "200|302"; then
      echo "✅ XWiki HTTP reachable at http://$XWIKI_HOST"
    else
      echo "❌ XWiki HTTP not responding properly"
    fi
  else
    echo "⚠️ No Ingress found for XWiki in $ns"
  fi

  echo "===================================================="
  echo
done
