#!/bin/bash
set -euo pipefail

echo "=== Purge ARC (Actions Runner Controller) ==="

# 1. Supprimer les pods ARC
kubectl -n actions-runner-system delete pod -l app.kubernetes.io/name=actions-runner-controller --ignore-not-found

# 2. Supprimer les secrets ARC (sealed et déchiffrés)
kubectl -n actions-runner-system delete secret actions-runner-controller --ignore-not-found
kubectl -n actions-runner-system delete secret controller-manager --ignore-not-found
kubectl -n actions-runner-system delete sealedsecret actions-runner-controller --ignore-not-found
kubectl -n actions-runner-system delete sealedsecret controller-manager --ignore-not-found

# 3. Supprimer les CRDs runners (si déjà créés mais bloqués)
kubectl delete runnerdeployments.actions.summerwind.dev --all --ignore-not-found
kubectl delete runners.actions.summerwind.dev --all --ignore-not-found
kubectl delete runnersets.actions.summerwind.dev --all --ignore-not-found

# 4. Supprimer le HelmRelease bloqué
kubectl -n actions-runner-system delete helmrelease actions-runner-controller --ignore-not-found

echo "=== Purge terminée. Forcer reconcile ==="

# 5. Reconcile pour recréer
flux reconcile kustomization arc-repo -n flux-system --with-source
flux reconcile kustomization arc-release -n flux-system --with-source

# 6. Vérification rapide
kubectl -n actions-runner-system get pods
