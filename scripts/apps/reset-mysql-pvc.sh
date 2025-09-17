#!/usr/bin/env bash
set -euo pipefail

NS="ns-open4goods-recette"
STS="mysql-xwiki"
PVC_NAME="${STS}-persistent-storage-${STS}-0"
KS_NAME="mysql-xwiki"
FLUX_NS="flux-system"

echo "🗑 Suppression du StatefulSet $STS (sans toucher aux PVC)..."
kubectl -n "$NS" delete statefulset "$STS" --cascade=orphan || true

echo "🗑 Suppression du PVC $PVC_NAME..."
kubectl -n "$NS" delete pvc "$PVC_NAME" --ignore-not-found

echo "🔍 Recherche du PV associé..."
PV=$(kubectl get pv -o jsonpath="{.items[?(@.spec.claimRef.name=='$PVC_NAME')].metadata.name}" || true)

if [[ -n "$PV" ]]; then
  echo "⚠️ PV trouvé: $PV → suppression avec patch finalizers"
  # Patch pour enlever les finalizers
  kubectl patch pv "$PV" -p '{"metadata":{"finalizers":null}}' --type=merge || true
  kubectl delete pv "$PV" || true
else
  echo "✅ Aucun PV associé trouvé"
fi

echo "🔄 Forçage reconcile de Flux sur $KS_NAME..."
flux reconcile kustomization "$KS_NAME" -n "$FLUX_NS" --with-source

echo "✨ Reset terminé : le StatefulSet $STS va recréer un PVC/PV propre."
