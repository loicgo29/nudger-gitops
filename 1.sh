#!/bin/bash
# purge-longhorn-orphans.sh
# Purge les volumes Longhorn orphelins (detached/unknown/faulted) et nettoie les réplicas associés

set -euo pipefail

NAMESPACE="longhorn-system"

echo "🔍 Recherche des volumes orphelins..."
orphans=$(kubectl -n $NAMESPACE get volumes.longhorn.io \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.state}{"\t"}{.status.robustness}{"\n"}{end}' \
  | grep -E 'detached.*(unknown|faulted)' \
  | awk '{print $1}')

if [[ -z "$orphans" ]]; then
  echo "✅ Aucun volume orphelin trouvé."
  exit 0
fi

echo "⚠️ Volumes orphelins détectés :"
echo "$orphans" | sed 's/^/ - /'

read -p "Confirmer la suppression de ces volumes ? (yes/NO): " confirm
if [[ "$confirm" != "yes" ]]; then
  echo "❌ Annulé par l'utilisateur."
  exit 1
fi

for vol in $orphans; do
  echo "🗑 Suppression du volume $vol..."
  kubectl -n $NAMESPACE delete volumes.longhorn.io "$vol" || true

  echo "🔍 Nettoyage des réplicas liés au volume $vol..."
  replicas=$(kubectl -n $NAMESPACE get replicas.longhorn.io \
    -o jsonpath="{range .items[?(@.spec.volumeName=='$vol')]}{.metadata.name}{'\n'}{end}")

  if [[ -n "$replicas" ]]; then
    for rep in $replicas; do
      echo "   ➡️ Suppression du réplica $rep"
      kubectl -n $NAMESPACE delete replicas.longhorn.io "$rep" || true
    done
  fi
done

echo "✅ Purge terminée. Tu peux maintenant retenter :"
echo "kubectl -n longhorn-system patch nodes.longhorn.io master1 --type=json -p='[{\"op\": \"remove\", \"path\": \"/spec/disks/disk-extra-sdc\"}]'"
