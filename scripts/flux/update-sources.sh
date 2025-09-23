#!/usr/bin/env bash
set -euo pipefail

OUTFILE="scripts/flux/sources.json"

echo "📦 Collecte de l'état des sources Flux..."
kubectl get gitrepositories,helmrepositories,helmcharts,helmreleases,kustomizations -A -o json > "$OUTFILE"

echo "✅ Snapshot sauvegardé dans $OUTFILE"
echo

echo "🔍 Vérification : Kustomizations qui pointent encore vers 'gitops' :"
jq -r '
  .items[]
  | select(.kind=="Kustomization")
  | select(.spec.sourceRef.name=="gitops")
  | [.metadata.namespace, .metadata.name, .spec.path]
  | @tsv
' "$OUTFILE"

echo
echo "🩺 Vérification : état des Kustomizations"
NOT_READY=$(kubectl get kustomizations.kustomize.toolkit.fluxcd.io -A \
  --no-headers 2>/dev/null | grep -v "True")

if [[ -z "$NOT_READY" ]]; then
  echo "✅ Toutes les Kustomizations sont Ready"
else
  echo "⚠️ Certaines Kustomizations ne sont pas Ready :"
  echo "$NOT_READY"
  exit 1
fi
