#!/usr/bin/env bash
# Script pour relancer Flux sur observability et vérifier l'état

set -euo pipefail

NS_FLUX="flux-system"
KS_NAME="observability"
HR_NAME="grafana"

kubectl annotate --overwrite kustomization observability -n flux-system reconcile.fluxcd.io/requestedAt="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo "🔄 Reconciliation du GitRepository 'gitops'..."
flux reconcile source git gitops -n "$NS_FLUX"

echo "🔄 Reconciliation du Kustomization '$KS_NAME'..."
echo "flux reconcile kustomization $KS_NAME -n $NS_FLUX --with-source"
flux reconcile kustomization "$KS_NAME" -n "$NS_FLUX" --with-source

echo
echo "📊 Liste des objets générés par la Kustomization..."
flux build kustomization "$KS_NAME" \
  --path ./infra/observability/overlays/lab \
  | yq '.kind + " " + .metadata.name'

echo
echo "📊 Statut du HelmRelease Grafana (si présent)..."
if kubectl -n "$KS_NAME" get helmrelease "$HR_NAME" >/dev/null 2>&1; then
  flux get helmrelease "$HR_NAME" -n "$KS_NAME"
  kubectl -n "$KS_NAME" describe helmrelease "$HR_NAME" | tail -n 50
else
  echo "⚠️  HelmRelease $HR_NAME absent dans $KS_NAME"
fi

echo
echo "📦 Vérification du HelmChart rendu par Flux (si présent)..."
if kubectl -n "$NS_FLUX" get helmchart "$KS_NAME"-"$HR_NAME" >/dev/null 2>&1; then
  kubectl -n "$NS_FLUX" get helmchart "$KS_NAME"-"$HR_NAME" -o yaml | yq '.spec,.status'
else
  echo "⚠️  HelmChart $KS_NAME-$HR_NAME absent dans $NS_FLUX"
fi

echo
echo "🔍 Vérification Helm interne..."
helm ls -n "$KS_NAME"

echo
echo "📦 Vérification des pods Grafana/Prometheus..."
kubectl -n "$KS_NAME" get pods

echo
echo "📡 Vérification des services Grafana/Prometheus..."
kubectl -n "$KS_NAME" get svc

echo
echo "✅ Terminé. Pour debug plus fin :"
echo "   kubectl -n $NS_FLUX logs deploy/kustomize-controller -f | grep $KS_NAME"
