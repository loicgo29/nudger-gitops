#!/usr/bin/env bash
set -euo pipefail

check_ok() {
  local status=$1
  local label=$2
  if [[ "$status" -eq 0 ]]; then
    echo "✅ $label"
  else
    echo "❌ $label"
  fi
}

echo "=== 🌐 Cluster summary ==="

# Nodes Ready
kubectl get nodes --no-headers | grep -q " Ready "
check_ok $? "Nodes Ready"

# Flux Kustomizations Ready
kubectl get kustomizations.kustomize.toolkit.fluxcd.io -A --no-headers | grep -q "False" && FAIL=1 || FAIL=0
check_ok $FAIL "Flux Kustomizations"

# XWiki pod Ready
kubectl get pod -n ns-open4goods-recette -l app=xwiki \
  -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null \
  | grep -q "true"
check_ok $? "XWiki pod"

# XWiki ingress
curl -skL --max-time 5 -o /dev/null -w "%{http_code}" https://xwiki.nudger.logo-solutions.fr \
  | grep -q "200"
check_ok $? "XWiki ingress"

# MySQL pod Ready
kubectl get pod -n ns-open4goods-recette -l app=mysql-xwiki \
  -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null \
  | grep -q "true"
check_ok $? "MySQL pod"

# Grafana ingress
curl -skL --max-time 5 -o /dev/null -w "%{http_code}" https://grafana.nudger.logo-solutions.fr \
  | grep -q "200"
check_ok $? "Grafana ingress"

# Actions Runner Controller
kubectl get pod -n actions-runner-system \
  -l app.kubernetes.io/name=actions-runner-controller \
  -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null \
  | grep -q "true"
check_ok $? "Actions Runner Controller"

echo "=== ✅ Health summary finished ==="
