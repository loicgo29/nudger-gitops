#!/usr/bin/env bash
set -euo pipefail

echo "🔧 Correction des chemins obsolètes dans les kustomization.yaml..."

find . -name "kustomization.yaml" -type f | while read -r file; do
  sed -i \
    -e 's|helmrelease-kube-prometheus-stack.yaml|../../observability/overlays/lab/helmrelease-kube-prometheus-stack.yaml|g' \
    -e 's|helmrepository-prometheus-community.yaml|../../observability/base/helmrepository-prometheus-community.yaml|g' \
    -e 's|ingress-nginx-helmrepository-prometheus-community.yaml|../../observability/base/helmrepository-prometheus-community.yaml|g' \
    "$file"
  echo "✅ Corrigé : $file"
done

echo "🎉 Tous les chemins obsolètes ont été corrigés."
