#!/usr/bin/env bash
set -euo pipefail

echo "🧹 [CLEANUP] Suppression forcée des finalizers (HelmRelease, HelmChart, Kustomization)"
for kind in helmreleases.helm.toolkit.fluxcd.io helmcharts.source.toolkit.fluxcd.io kustomizations.kustomize.toolkit.fluxcd.io; do
  for res in $(kubectl get $kind -A -o name 2>/dev/null || true); do
    echo "⚡ Patching finalizers: $res"
    kubectl patch $res --type merge -p '{"metadata":{"finalizers":[]}}' || true
  done
done
# 1. Supprimer l’ancien HelmRelease (s’il existe)
kubectl -n ns-cert-manager delete helmrelease helm-cert-manager --ignore-not-found

# 2. Supprimer le HelmChart généré par Flux
kubectl -n flux-system delete helmchart ns-cert-manager-helmrepo-cert-manager --ignore-not-found

echo "🧹 [CLEANUP] Suppression cert-manager"
kubectl delete helmrelease helm-cert-manager -n ns-cert-manager --ignore-not-found --wait=false || true
kubectl delete helmchart ns-cert-manager-helmrepo-cert-manager -n flux-system --ignore-not-found --wait=false || true
kubectl delete helmrepository helmrepo-cert-manager -n flux-system --ignore-not-found --wait=false || true

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
