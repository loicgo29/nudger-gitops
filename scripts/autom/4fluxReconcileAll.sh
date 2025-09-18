#!/usr/bin/env bash
set -euo pipefail

echo
echo "🚀 [STEP 1] Build + Dry-Run local (0fluxBuildAllDryRun.sh)"
./scripts/autom/0fluxBuildAllDryRun.sh

echo
echo "🚀 [STEP 2] Reconcile Sources (2fluxReconcileSources.sh)"
./scripts/autom/2fluxReconcileSources.sh

echo
echo "🚀 [STEP 3] Reconcile Kustomizations (3fluxReconcileKustomizations.sh)"
./scripts/autom/3fluxReconcileKustomizations.sh
