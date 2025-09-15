#!/usr/bin/env bash
set -euo pipefail

echo "🔄 Reconciling all Kustomizations (namespaces first)"

# 1. Reconcile des Kustomizations 'namespaces' en priorité
flux get kustomizations -A | tail -n +2 | awk '{print $1 "/" $2}' | grep "infra-namespaces" | while read item; do
  ns=$(echo $item | cut -d/ -f1)
  name=$(echo $item | cut -d/ -f2)
  echo "🔄 flux reconcile kustomization $name -n $ns --with-source"
  flux reconcile kustomization $name -n $ns --with-source
done

# 2. Reconcile des autres Kustomizations
flux get kustomizations -A | tail -n +2 | awk '{print $1 "/" $2}' | grep -v "infra-namespaces" | while read item; do
  ns=$(echo $item | cut -d/ -f1)
  name=$(echo $item | cut -d/ -f2)
  echo "🔄 flux reconcile kustomization $name -n $ns --with-source"
  flux reconcile kustomization $name -n $ns --with-source
done
