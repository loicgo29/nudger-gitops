#!/usr/bin/env bash
set -euo pipefail

NAMESPACES=("ns-open4goods-recette" "flux-system" "actions-runner-system" "observability" "kyverno")
SERVICES=("xwiki" "mysql-xwiki" "grafana" "ingress-nginx-controller")

echo "=== 🌐 Cluster nodes ==="
kubectl get nodes -o wide

echo -e "\n=== 📦 Kustomizations (Flux) ==="
kubectl get kustomizations.kustomize.toolkit.fluxcd.io -A

for ns in "${NAMESPACES[@]}"; do
  echo -e "\n=== 🛠 Pods in namespace: $ns ==="
  kubectl get pods -n "$ns" -o wide
done

echo -e "\n=== 🔗 Services / Ingress health ==="
for svc in "${SERVICES[@]}"; do
  echo "--- $svc ---"
  kubectl get svc -A | grep "$svc" || echo "❌ Service $svc not found"
  kubectl get ingress -A | grep "$svc" || echo "ℹ️ No ingress for $svc"
done

echo -e "\n=== 🚦 Readiness check XWiki ==="
XWIKI_POD=$(kubectl get pod -n ns-open4goods-recette -l app=xwiki -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [[ -n "$XWIKI_POD" ]]; then
  kubectl exec -n ns-open4goods-recette "$XWIKI_POD" -- curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/bin/view/Main/ || echo "❌ XWiki curl failed"
else
  echo "❌ No XWiki pod found"
fi

echo -e "\n✅ Healthcheck terminé"
