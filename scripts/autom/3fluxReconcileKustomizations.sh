#!/usr/bin/env bash
set -euo pipefail

run() {
  echo "🔄 Reconciling $1/$2"
  flux reconcile kustomization "$2" -n "$1" --with-source
}

echo "🔄 Reconciling all Kustomizations (namespaces first)"

# Récupération JSON + parsing fiable
kustomizations=$(flux get kustomizations --all-namespaces | tail -n +2 | awk '{print $1 "/" $2}' | sed '/^$/d')
# 1. Forcer les namespaces d’abord
for item in $(echo "$kustomizations" | grep -w "infra-namespaces"); do
  ns=$(echo "$item" | cut -d/ -f1)
  name=$(echo "$item" | cut -d/ -f2)
  run "$ns" "$name"
done

# 2. Puis le reste
for item in $(echo "$kustomizations" | grep -vw "infra-namespaces"); do
  ns=$(echo "$item" | cut -d/ -f1)
  name=$(echo "$item" | cut -d/ -f2)
  run "$ns" "$name"
done
