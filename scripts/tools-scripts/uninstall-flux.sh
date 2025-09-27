#!/usr/bin/env bash
set -euo pipefail

NS="flux-system"

echo "🔎 Vérification : présence de Flux dans le cluster..."
if ! kubectl get ns "$NS" >/dev/null 2>&1; then
  echo "✅ Namespace $NS introuvable. Flux semble déjà désinstallé."
  exit 0
fi

echo "🧹 Suppression des Kustomizations et HelmReleases..."
kubectl delete kustomizations.kustomize.toolkit.fluxcd.io --all -A || true
kubectl delete helmreleases.helm.toolkit.fluxcd.io --all -A || true
kubectl delete helmrepositories.source.toolkit.fluxcd.io --all -A || true
kubectl delete gitrepositories.source.toolkit.fluxcd.io --all -A || true
kubectl delete buckets.source.toolkit.fluxcd.io --all -A || true
kubectl delete ocirepositories.source.toolkit.fluxcd.io --all -A || true

echo "🛑 Suppression des composants Flux (controllers)..."
if [ -f "./clusters/recette/flux-system/gotk-components.yaml" ]; then
  kubectl delete -f ./clusters/recette/flux-system/gotk-components.yaml --ignore-not-found
elif [ -f "./clusters/lab/flux-system/gotk-components.yaml" ]; then
  kubectl delete -f ./clusters/lab/flux-system/gotk-components.yaml --ignore-not-found
else
  echo "⚠️  Fichier gotk-components.yaml introuvable dans ./clusters/*/flux-system/"
  echo "   Suppression manuelle des deployments Flux..."
  kubectl -n "$NS" delete deployment,svc --all || true
fi

echo "🗑 Suppression des CRDs Flux..."
kubectl get crds | grep "toolkit.fluxcd.io" | awk '{print $1}' | \
  xargs -r kubectl delete crd

echo "💥 Suppression du namespace $NS..."
kubectl delete ns "$NS" --ignore-not-found

echo "✅ Désinstallation Flux terminée !"
