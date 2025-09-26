#!/usr/bin/env bash
set -euo pipefail

NAMESPACES=("ns-open4goods-integration" "ns-open4goods-recette")

echo "🔎 Sanity check XWiki + MySQL for namespaces: ${NAMESPACES[*]}"
echo "----------------------------------------------------"

for ns in "${NAMESPACES[@]}"; do
  echo "🟢 Checking namespace: $ns"
  echo "----------------------------------------------------"

  # 1️⃣ HelmReleases
  echo "1️⃣ HelmRelease:"
  kubectl -n "$ns" get helmrelease xwiki mysql-xwiki 2>/dev/null || echo "❌ HelmRelease(s) missing"

  # 2️⃣ StatefulSets
  echo -e "\n2️⃣ StatefulSets:"
  sts=$(kubectl -n "$ns" get sts -o name | grep -E 'xwiki|mysql-xwiki' || true)
  if [[ -z "$sts" ]]; then
    echo "❌ No xwiki/mysql statefulsets found"
  else
    kubectl -n "$ns" get sts | grep -E 'xwiki|mysql-xwiki'
  fi

  # 3️⃣ Pods
  echo -e "\n3️⃣ Pods:"
  pods=$(kubectl -n "$ns" get pods -o name | grep -E 'xwiki|mysql-xwiki' || true)
  if [[ -z "$pods" ]]; then
    echo "❌ No xwiki/mysql pods running"
  else
    kubectl -n "$ns" get pods -o wide | grep -E 'xwiki|mysql-xwiki'
  fi

  # 4️⃣ PVC
  echo -e "\n4️⃣ PVC:"
  pvc=$(kubectl -n "$ns" get pvc -o name | grep -E 'xwiki|mysql' || true)
  if [[ -z "$pvc" ]]; then
    echo "❌ No xwiki/mysql PVCs found"
  else
    kubectl -n "$ns" get pvc | grep -E 'xwiki|mysql'
  fi

  # 5️⃣ ConfigMap / Secret
  echo -e "\n5️⃣ ConfigMap / Secret XWiki:"
  if kubectl -n "$ns" get cm xwiki &>/dev/null; then
    kubectl -n "$ns" get cm xwiki -o jsonpath='{.data}' | jq .
  else
    echo "❌ ConfigMap xwiki missing"
  fi

  if kubectl -n "$ns" get secret xwiki &>/dev/null; then
    echo "DB_PASSWORD: $(kubectl -n "$ns" get secret xwiki -o jsonpath='{.data.DB_PASSWORD}' | base64 -d)"
  else
    echo "❌ Secret xwiki missing"
  fi

  # 6️⃣ DB connectivity
  echo -e "\n6️⃣ Database connectivity test:"
  if kubectl -n "$ns" get sts mysql-xwiki &>/dev/null; then
    if kubectl -n "$ns" exec -it mysql-xwiki-0 -- \
      mariadb -uxwiki -p"$(kubectl -n "$ns" get secret xwiki -o jsonpath='{.data.DB_PASSWORD}' | base64 -d)" xwiki \
      -e "SELECT COUNT(*) FROM xwikidoc;" &>/tmp/mysqltest; then
      echo "✅ DB query succeeded: $(cat /tmp/mysqltest | tail -n1)"
    else
      echo "❌ MariaDB connection failed"
    fi
  else
    echo "⚠️ No mysql-xwiki statefulset, skipping DB test"
  fi

  # 7️⃣ HTTP check
  echo -e "\n7️⃣ XWiki HTTP check:"
  ingress=$(kubectl -n "$ns" get ingress xwiki -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || true)
  if [[ -z "$ingress" ]]; then
    echo "⚠️ No Ingress found for XWiki in $ns"
  else
    url="https://${ingress}/bin/view/Main/"
    code=$(curl -sk -o /dev/null -w "%{http_code}" "$url" || true)
    if [[ "$code" == "200" || "$code" == "302" ]]; then
      echo "✅ XWiki HTTP reachable ($code) → $url"
    else
      echo "❌ XWiki HTTP check failed ($code) → $url"
    fi
  fi

  echo "===================================================="
done
