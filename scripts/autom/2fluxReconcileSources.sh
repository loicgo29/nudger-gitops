#!/usr/bin/env bash
set -euo pipefail

# Reconcilier toutes les sources Git
flux get sources git -A | tail -n +2 | awk '{print $1 "/" $2}' | while read repo; do
  ns=$(echo $repo | cut -d/ -f1)
  name=$(echo $repo | cut -d/ -f2)
  echo "🔄 Reconciling GitRepository $name in $ns"
  flux reconcile source git $name -n $ns
done

# Reconcilier toutes les sources Helm
flux get sources helm -A | tail -n +2 | awk '{print $1 "/" $2}' | while read repo; do
  ns=$(echo $repo | cut -d/ -f1)
  name=$(echo $repo | cut -d/ -f2)
  echo "🔄 Reconciling HelmRepository $name in $ns"
  flux reconcile source helm $name -n $ns
done
