#!/usr/bin/env bash
set -euo pipefail

run() {
  echo "🔄 $*"
  "$@"
}

echo "🔄 Reconciling all Kustomizations (namespaces first)"

# 1. Reconcile des Kustomizations 'infra-namespaces'
flux get kustomizations -A | tail -n +2 | awk '{print $1 "/" $2}' | grep "infra-namespaces" | while read item; do
  ns=$(echo $item | cut -d/ -f1)
  name=$(echo $item | cut -d/ -f2)
  [[ -z "$ns" || -z "$name" ]] && continue
  run flux reconcile kustomization "$name" -n "$ns" --with-source
done

# 2. Reconcile des autres
flux get kustomizations -A | tail -n +2 | awk '{print $1 "/" $2}' | grep -v "infra-namespaces" | while read item; do
  ns=$(echo $item | cut -d/ -f1)
  name=$(echo $item | cut -d/ -f2)
  [[ -z "$ns" || -z "$name" ]] && continue
  run flux reconcile kustomization "$name" -n "$ns" --with-source
done
