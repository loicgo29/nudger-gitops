#!/usr/bin/env bash
set -euo pipefail

echo "🧹 Cleanup complet Longhorn : détacher + supprimer volumes + PVs"
echo "⚠️ ATTENTION : destruction irréversible des données Longhorn + PV associés !"

NAMESPACE="longhorn-system"

# Récupère tous les volumes Longhorn
VOLUMES=$(kubectl -n $NAMESPACE get volumes -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')

if [[ -z "$VOLUMES" ]]; then
  echo "✅ Aucun volume trouvé"
  exit 0
fi

for vol in $VOLUMES; do
  echo "----------------------------------------------------"
  echo "➡️  Traitement du volume: $vol"

  STATE=$(kubectl -n $NAMESPACE get volume "$vol" -o jsonpath='{.status.state}')
  echo "  📊 State actuel: $STATE"

  if [[ "$STATE" == "attached" ]]; then
    echo "  🔒 Disable frontend..."
    kubectl -n $NAMESPACE patch volume "$vol" \
      --type=merge -p '{"spec":{"disableFrontend":true}}' >/dev/null || true

    echo "  📤 Detach du volume..."
    kubectl -n $NAMESPACE patch volume "$vol" \
      --type=merge -p '{"spec":{"nodeID":""}}' >/dev/null || true
  fi

  # Récupère le PV associé
  PV=$(kubectl get pv -o jsonpath="{.items[?(@.spec.csi.volumeHandle=='$vol')].metadata.name}" || true)
  if [[ -n "$PV" ]]; then
    echo "  🗑️ Suppression du PV $PV"
    kubectl delete pv "$PV" --wait=false || true
  else
    echo "  ⚠️ Aucun PV associé trouvé"
  fi

  echo "  ❌ Suppression du volume Longhorn $vol"
  kubectl -n $NAMESPACE delete volume "$vol" --wait=false || true

  echo "✅ Volume $vol supprimé"
done

echo "🎉 Cleanup Longhorn terminé."
