#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel)"
cd "$ROOT_DIR"

echo "🚀 [STEP 1] Build + Dry-Run local (0fluxBuildAllDryRun.sh)"
if ./scripts/autom/0fluxBuildAllDryRun.sh; then
  echo "✅ Step 1 terminé avec succès"
else
  echo "⚠️ Step 1 a rencontré des erreurs (voir logs)"
fi
echo

echo "🚀 [STEP 2] Reconcile Sources (2fluxReconcileSources.sh)"
if ./scripts/autom/2fluxReconcileSources.sh; then
  echo "✅ Step 2 terminé avec succès"
else
  echo "⚠️ Step 2 a rencontré des erreurs (voir logs)"
fi
echo

echo "🚀 [STEP 3] Reconcile Kustomizations (3fluxReconcileKustomizations.sh)"
if ./scripts/autom/3fluxReconcileKustomizations.sh; then
  echo "✅ Step 3 terminé avec succès"
else
  echo "⚠️ Step 3 a rencontré des erreurs (voir logs)"
fi
echo

echo "🎉 Pipeline complet terminé"
