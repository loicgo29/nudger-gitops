#!/usr/bin/env bash
set -euo pipefail

echo "🧹 [FORCE CLEANUP] Suppression de observability et promtail cassés"

# Supprimer la Kustomization observability si elle existe
echo "+ kubectl delete kustomization observability -n flux-system --ignore-not-found --wait=false"
kubectl delete kustomization observability -n flux-system --ignore-not-found --wait=false || true

# Supprimer le HelmRelease promtail cassé si présent
echo "+ kubectl delete helmrelease promtail -n ns-logging --ignore-not-found --wait=false"
kubectl delete helmrelease promtail -n ns-logging --ignore-not-found --wait=false || true

# Supprimer aussi le HelmChart associé qui traîne dans flux-system
echo "+ kubectl delete helmchart ns-logging-promtail -n flux-system --ignore-not-found --wait=false"
kubectl delete helmchart ns-logging-promtail -n flux-system --ignore-not-found --wait=false || true

echo
echo "🚀 [STEP 1] Build + Dry-Run local (0fluxBuildAllDryRun.sh)"
./scripts/autom/0fluxBuildAllDryRun.sh

echo
echo "🚀 [STEP 2] Reconcile Sources (2fluxReconcileSources.sh)"
./scripts/autom/2fluxReconcileSources.sh

echo
echo "🚀 [STEP 3] Reconcile Kustomizations (3fluxReconcileKustomizations.sh)"
./scripts/autom/3fluxReconcileKustomizations.sh

echo
echo "🚀 [STEP 4] Reconcile HelmReleases (--with-source)"
for hr in $(kubectl get helmrelease -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}'); do
  ns="${hr%%/*}"
  name="${hr##*/}"
  echo "🔄 flux reconcile helmrelease ${name} -n ${ns} --with-source"
  flux reconcile helmrelease "${name}" -n "${ns}" --with-source || true
done
