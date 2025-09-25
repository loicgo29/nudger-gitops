#!/usr/bin/env bash
set -euo pipefail

NAMESPACES=("ns-open4goods-recette" "ns-open4goods-integration")

for ns in "${NAMESPACES[@]}"; do
  echo "🔧 Patch des finalizers dans le namespace $ns"

  # Ressources classiques
  for res in helmrelease statefulset pvc secret configmap; do
    for name in $(kubectl -n "$ns" get $res -o name 2>/dev/null | grep xwiki || true); do
      echo "  ➡️  Patching $name"
      kubectl -n "$ns" patch $name --type=merge -p '{"metadata":{"finalizers":[]}}' || true
    done
  done

  echo "🗑️ Suppression forcée des pods Terminating dans $ns"
  for pod in $(kubectl -n "$ns" get pod --field-selector=status.phase=Pending,status.phase=Failed  -o name 2>/dev/null | grep xwiki || true); do
    echo "  ➡️  Deleting $pod"
    kubectl -n "$ns" delete $pod --force --grace-period=0 || true
  done
done

# Ressources Longhorn (volumes + replicas)
echo "🔧 Patch des finalizers Longhorn (volumes/replicas)"

for res in volumes.longhorn.io replicas.longhorn.io; do
  for name in $(kubectl -n longhorn-system get $res -o name 2>/dev/null | grep xwiki || true); do
    echo "  ➡️  Patching $name"
    kubectl -n longhorn-system patch $name --type=merge -p '{"metadata":{"finalizers":[]}}' || true
  done
done

echo "✅ Nettoyage terminé"
