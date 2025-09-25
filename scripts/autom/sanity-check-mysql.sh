#!/usr/bin/env bash
set -euo pipefail

# Namespaces cibles
NAMESPACES=("ns-open4goods-integration" "ns-open4goods-recette")

echo "🔎 Sanity check MySQL for namespaces: ${NAMESPACES[*]}"
echo "----------------------------------------------------"

for ns in "${NAMESPACES[@]}"; do
  echo ""
  echo "🟢 Checking namespace: $ns"
  echo "----------------------------------------------------"

  # 1️⃣ HelmRelease
  echo "1️⃣ HelmRelease:"
  if kubectl get helmrelease -n "$ns" mysql-xwiki &>/dev/null; then
    kubectl get helmrelease -n "$ns" mysql-xwiki -o wide
  else
    echo "❌ HelmRelease not found"
  fi
  echo ""

  # 2️⃣ Secret
  echo "2️⃣ Secret mysql-xwiki:"
  if kubectl get secret -n "$ns" mysql-xwiki &>/dev/null; then
    keys=$(kubectl get secret -n "$ns" mysql-xwiki -o jsonpath='{.data}' | jq -r 'keys[]')
    echo "✅ Secret mysql-xwiki present with keys: $keys"
  else
    echo "❌ Secret mysql-xwiki missing"
  fi
  echo ""

  # 3️⃣ Pods
  echo "3️⃣ Pods MySQL:"
  pods=$(kubectl get pods -n "$ns" -l app.kubernetes.io/instance=mysql-xwiki --no-headers --ignore-not-found || true)
  if [[ -n "$pods" ]]; then
    kubectl get pods -n "$ns" -l app.kubernetes.io/instance=mysql-xwiki -o wide
  else
    echo "❌ No MySQL pods found"
  fi
  echo ""

  # 4️⃣ PVC
  echo "4️⃣ PVC:"
  kubectl get pvc -n "$ns" | grep mysql-xwiki || echo "❌ No PVC found"
  echo ""

  # 5️⃣ Logs
  echo "5️⃣ Logs MySQL (dernier 20 lignes):"
  pod=$(kubectl get pod -n "$ns" -l app.kubernetes.io/instance=mysql-xwiki -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [[ -n "$pod" ]]; then
    kubectl logs -n "$ns" "$pod" --tail=20 || echo "❌ No logs available"
  else
    echo "❌ No pod to fetch logs"
  fi
  echo ""

  # 6️⃣ Test connexion MySQL root
  echo "6️⃣ Test connexion MySQL root:"
  if kubectl get secret -n "$ns" mysql-xwiki &>/dev/null; then
    ROOT_PASS=$(kubectl get secret -n "$ns" mysql-xwiki -o jsonpath='{.data.mysql-root-password}' | base64 -d)
    if [[ -n "$pod" ]]; then
      kubectl exec -n "$ns" "$pod" -c mysql -- \
        mysqladmin ping -uroot -p"$ROOT_PASS" || echo "❌ Connexion MySQL root failed"
    else
      echo "❌ No pod to exec into"
    fi
  else
    echo "❌ Root password not found in secret"
  fi

  echo "----------------------------------------------------"
done

echo "✅ Sanity check terminé."
