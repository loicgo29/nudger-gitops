#!/usr/bin/env bash
set -euo pipefail

NS="longhorn-system"

echo "🧹 Nettoyage des volumes Longhorn en état 'faulted'..."
faulted_vols=$(kubectl -n $NS get volumes.longhorn.io \
  --no-headers -o custom-columns=":metadata.name,:status.robustness" | grep faulted | awk '{print $1}')

if [[ -z "$faulted_vols" ]]; then
  echo "✅ Aucun volume faulted trouvé."
else
  for vol in $faulted_vols; do
    echo "❌ Suppression du volume $vol"
    kubectl -n $NS delete volumes.longhorn.io "$vol" --ignore-not-found
  done
fi

echo "🧹 Nettoyage des replicas Longhorn liés aux volumes faulted..."
faulted_replicas=$(kubectl -n $NS get replicas.longhorn.io \
  --no-headers -o custom-columns=":metadata.name,:status.state" | grep faulted | awk '{print $1}')

if [[ -z "$faulted_replicas" ]]; then
  echo "✅ Aucun replica faulted trouvé."
else
  for rep in $faulted_replicas; do
    echo "❌ Suppression du replica $rep"
    kubectl -n $NS delete replicas.longhorn.io "$rep" --ignore-not-found
  done
fi

echo "✨ Nettoyage terminé."
