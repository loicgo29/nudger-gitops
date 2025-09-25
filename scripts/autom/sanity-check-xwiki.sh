#!/usr/bin/env bash
set -euo pipefail

NAMESPACES=("ns-open4goods-integration" "ns-open4goods-recette")

echo "🔎 Sanity check XWiki for namespaces: ${NAMESPACES[*]}"
echo "----------------------------------------------------"

for ns in "${NAMESPACES[@]}"; do
  echo ""
  echo "🟢 Checking namespace: $ns"
  echo "----------------------------------------------------"

  # 0️⃣ Flux Kustomization
  echo "0️⃣ Flux Kustomization:"
  ks_name="xwiki-$(echo "$ns" | cut -d'-' -f3)" # => xwiki-integration / xwiki-recette
  if kubectl -n flux-system get kustomization "$ks_name" &>/dev/null; then
    kubectl -n flux-system get kustomization "$ks_name"
  else
    echo "❌ Flux Kustomization $ks_name not found"
  fi
  echo ""

  # 0️⃣b HelmRepository
  echo "0️⃣b HelmRepository:"
  if kubectl -n flux-system get helmrepository helmrepo-xwiki &>/dev/null; then
    kubectl -n flux-system get helmrepository helmrepo-xwiki
  else
    echo "❌ HelmRepository helmrepo-xwiki not found"
  fi
  echo ""

  # 1️⃣ HelmRelease
  echo "1️⃣ HelmRelease:"
  if kubectl -n "$ns" get helmrelease xwiki &>/dev/null; then
    kubectl -n "$ns" get helmrelease xwiki
  else
    echo "❌ HelmRelease not found"
  fi
  echo ""

  # 2️⃣ Secret MySQL
  echo "2️⃣ Secret mysql-xwiki:"
  if kubectl -n "$ns" get secret mysql-xwiki &>/dev/null; then
    echo "✅ Secret mysql-xwiki present with keys:"
    kubectl -n "$ns" get secret mysql-xwiki -o jsonpath="{.data}" | jq 'keys'
  else
    echo "❌ Secret mysql-xwiki missing"
  fi
  echo ""

  # 3️⃣ Pods XWiki
  echo "3️⃣ Pods XWiki:"
  if kubectl -n "$ns" get pods -l app.kubernetes.io/instance=xwiki &>/dev/null; then
    kubectl -n "$ns" get pods -l app.kubernetes.io/instance=xwiki -o wide
  else
    echo "❌ No XWiki pods found"
  fi
  echo ""

  # 4️⃣ PVC
  echo "4️⃣ PVC:"
  if kubectl -n "$ns" get pvc -l app.kubernetes.io/instance=xwiki &>/dev/null; then
    kubectl -n "$ns" get pvc -l app.kubernetes.io/instance=xwiki
  else
    echo "❌ No PVC found"
  fi
  echo ""

  # 5️⃣ Logs
  echo "5️⃣ Logs XWiki (dernier 20 lignes):"
  pod=$(kubectl -n "$ns" get pod -l app.kubernetes.io/instance=xwiki -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || true)
  if [[ -n "$pod" ]]; then
    kubectl -n "$ns" logs "$pod" --tail=20 || echo "❌ Could not fetch logs"
  else
    echo "❌ No pod to fetch logs"
  fi
  echo ""

  # 6️⃣ Test HTTP
  echo "6️⃣ Test HTTP XWiki (via clusterIP):"
  svc=$(kubectl -n "$ns" get svc -l app.kubernetes.io/instance=xwiki -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || true)
  if [[ -n "$svc" ]]; then
    CLUSTER_IP=$(kubectl -n "$ns" get svc "$svc" -o jsonpath="{.spec.clusterIP}")
    if curl -s "http://$CLUSTER_IP:8080/bin/view/Main/WebHome" | grep -q "XWiki"; then
      echo "✅ XWiki responded successfully"
    else
      echo "❌ XWiki did not respond correctly"
    fi
  else
    echo "❌ No XWiki service found"
  fi
  echo "----------------------------------------------------"
done

echo "✅ Sanity check terminé."
