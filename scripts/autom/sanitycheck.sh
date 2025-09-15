#!/usr/bin/env bash
set -euo pipefail

echo "🔍 [SANITY CHECK] Vérification de l'état du cluster..."

# Vérification Pods
echo
echo "✅ [CHECK] Pods"
if kubectl get pods -A --no-headers | grep -vE 'Running|Completed' >/dev/null 2>&1; then
  echo "❌ Certains pods ne sont pas en état Running/Completed :"
  kubectl get pods -A --no-headers | grep -vE 'Running|Completed' || true
  exit 1
else
  echo "🎉 Tous les pods sont en état Running/Completed."
fi

# Vérification HelmRelease
echo
echo "✅ [CHECK] HelmReleases"
if kubectl get helmreleases -A --no-headers | grep False >/dev/null 2>&1; then
  echo "❌ Certaines HelmReleases ne sont pas prêtes :"
  kubectl get helmreleases -A | grep False || true
  exit 1
else
  echo "🎉 Toutes les HelmReleases sont prêtes."
fi

# Vérification Kustomizations
echo
echo "✅ [CHECK] Kustomizations"
if kubectl get kustomizations.kustomize.toolkit.fluxcd.io -A --no-headers | grep -v True >/dev/null 2>&1; then
  echo "❌ Certaines Kustomizations ne sont pas prêtes :"
  kubectl get kustomizations.kustomize.toolkit.fluxcd.io -A | grep -v True || true
  exit 1
else
  echo "🎉 Toutes les Kustomizations sont prêtes."
fi

# Vérification HelmCharts
echo
echo "✅ [CHECK] HelmCharts"
if kubectl get helmcharts.source.toolkit.fluxcd.io -A --no-headers | grep False >/dev/null 2>&1; then
  echo "❌ Certains HelmCharts ne sont pas prêts :"
  kubectl get helmcharts.source.toolkit.fluxcd.io -A | grep False || true
  exit 1
else
  echo "🎉 Tous les HelmCharts sont prêts."
fi

echo
echo "🚀 [SANITY CHECK] Tout est OK ✅"
