#!/bin/bash
set -euo pipefail
echo "=== Reset complet ARC (namespace actions-runner-system) ==="

# 1. Supprimer l'ancien HelmRelease (actions-runner-system)
kubectl -n actions-runner-system delete helmrelease actions-runner-controller --ignore-not-found
kubectl delete ns actions-runner-system --ignore-not-found

# 2. Supprimer les webhooks existants
kubectl delete mutatingwebhookconfiguration actions-runner-controller-mutating-webhook-configuration --ignore-not-found
kubectl delete validatingwebhookconfiguration actions-runner-controller-validating-webhook-configuration --ignore-not-found

# 3. Supprimer l'HelmChart en cache
kubectl -n flux-system delete helmchart actions-runner-system-actions-runner-controller --ignore-not-found
kubectl -n flux-system delete helmchart actions-runner-system-actions-runner-controller --ignore-not-found

# 4. Reconcile des sources
flux reconcile source helm actions-runner-controller -n flux-system

# 5. Relancer arc-release (il faut changer son namespace → actions-runner-system dans le HelmRelease YAML)
flux reconcile kustomization arc-release -n flux-system

# 6. Vérif
kubectl -n actions-runner-system get helmreleases
kubectl get mutatingwebhookconfigurations | grep actions-runner-controller || echo "❌ Pas de mutating webhook"
kubectl get validatingwebhookconfigurations | grep actions-runner-controller || echo "❌ Pas de validating webhook"

echo "=== Reset terminé ==="
