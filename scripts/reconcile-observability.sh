#!/usr/bin/env bash
# Script pour relancer Flux sur observability et vérifier l'état

set -euo pipefail

NS_FLUX="flux-system"
KS_NAME="observability"

echo "🔄 Reconciliation du GitRepository 'gitops'..."
flux reconcile source git gitops -n "$NS_FLUX"

echo "🔄 Reconciliation du Kustomization '$KS_NAME'..."
flux reconcile kustomization "$KS_NAME" -n "$NS_FLUX" --with-source

echo "⏳ Attente que les ressources soient prêtes..."
flux get kustomizations -n "$NS_FLUX" | grep "$KS_NAME"

echo
echo "📦 Vérification des pods Grafana/Prometheus dans namespace '$KS_NAME'..."
kubectl -n "$KS_NAME" get pods

echo
echo "📡 Vérification des services Grafana/Prometheus dans namespace '$KS_NAME'..."
kubectl -n "$KS_NAME" get svc

echo
echo "✅ Terminé. Si Grafana n'est toujours pas accessible, vérifie les logs :"
echo "   kubectl -n $NS_FLUX logs deploy/kustomize-controller -f | grep $KS_NAME"
