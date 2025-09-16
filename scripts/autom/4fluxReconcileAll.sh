#!/usr/bin/env bash
set -euo pipefail

echo "🧹 [CLEANUP] Suppression forcée des finalizers (HelmRelease, HelmChart, Kustomization)"
for kind in helmreleases.helm.toolkit.fluxcd.io helmcharts.source.toolkit.fluxcd.io kustomizations.kustomize.toolkit.fluxcd.io; do
  for res in $(kubectl get $kind -A -o name 2>/dev/null || true); do
    echo "⚡ Patching finalizers: $res"
    kubectl patch $res --type merge -p '{"metadata":{"finalizers":[]}}' || true
  done
done

echo "🧹 [CLEANUP] Suppression des anciens HelmRelease/Kustomization spécifiques"
kubectl delete helmrelease promtail -n ns-logging --ignore-not-found --wait=false || true
kubectl delete helmchart ns-logging-promtail -n flux-system --ignore-not-found --wait=false || true
kubectl delete kustomization observability -n flux-system --ignore-not-found --wait=false || true

echo
echo "🚀 [STEP 1] Build + Dry-Run local (0fluxBuildAllDryRun.sh)"
./scripts/autom/0fluxBuildAllDryRun.sh

echo
echo "🚀 [STEP 2] Reconcile Sources (2fluxReconcileSources.sh)"
./scripts/autom/2fluxReconcileSources.sh

echo
echo "🚀 [STEP 3] Reconcile Kustomizations (3fluxReconcileKustomizations.sh)"
./scripts/autom/3fluxReconcileKustomizations.sh
