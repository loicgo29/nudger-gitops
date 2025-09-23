#!/usr/bin/env bash
set -euo pipefail

run() {
  echo "🔄 $*"
  "$@"
}

echo "🔄 Reconciling all Kustomizations (namespaces first)"

# Récupération des Kustomizations
kustomizations=$(flux get kustomizations -A | tail -n +2 | awk '{print $1 "/" $2}' | sed '/^$/d')

# 1. Forcer l’ordre : namespaces d’abord
for item in $(echo "$kustomizations" | grep "infra-namespaces"); do
  ns=$(echo $item | cut -d/ -f1)
  name=$(echo $item | cut -d/ -f2)
  run flux reconcile kustomization "$name" -n "$ns" --with-source
done

# 2. Puis le reste
for item in $(echo "$kustomizations" | grep -v "infra-namespaces"); do
  ns=$(echo $item | cut -d/ -f1)
  name=$(echo $item | cut -d/ -f2)
  run flux reconcile kustomization "$name" -n "$ns" --with-source
done
