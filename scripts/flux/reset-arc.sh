#!/bin/bash
set -euo pipefail
echo "=== Reset complet ARC (Actions Runner Controller) ==="

# 1. Supprimer l'HelmRelease ARC
kubectl -n arc-system delete helmrelease actions-runner-controller --ignore-not-found

# 2. Supprimer le HelmChart en cache
kubectl -n flux-system delete helmchart arc-system-actions-runner-controller --ignore-not-found

# 3. Supprimer les webhooks existants
kubectl delete mutatingwebhookconfiguration actions-runner-controller-mutating-webhook-configuration --ignore-not-found
kubectl delete validatingwebhookconfiguration actions-runner-controller-validating-webhook-configuration --ignore-not-found

# 4. Purger aussi le GitRepository (force Flux à re-fetch ton repo Git)
kubectl -n flux-system delete gitrepository gitops --ignore-not-found

# 5. Forcer reconcile des sources
flux reconcile source git gitops -n flux-system
flux reconcile source helm actions-runner-controller -n flux-system
flux reconcile kustomization arc-release -n flux-system

# 6. Réinstaller le HelmRelease ARC
flux reconcile helmrelease actions-runner-controller -n arc-system

# 7. Vérifier que les webhooks sont recréés et corrects
echo "=== Vérification des webhooks recréés ==="
kubectl get mutatingwebhookconfigurations | grep actions-runner-controller || echo "❌ Aucun mutating webhook trouvé"
kubectl get validatingwebhookconfigurations | grep actions-runner-controller || echo "❌ Aucun validating webhook trouvé"

echo "=== Reset terminé ==="
