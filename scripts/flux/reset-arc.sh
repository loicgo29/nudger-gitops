#!/bin/bash
set -euo pipefail
echo "=== Reset complet ARC Webhooks ==="

# 1. Supprimer l'HelmRelease ARC
kubectl -n arc-system delete helmrelease actions-runner-controller --ignore-not-found

# 2. Supprimer les webhooks existants
kubectl delete mutatingwebhookconfiguration actions-runner-controller-mutating-webhook-configuration --ignore-not-found
kubectl delete validatingwebhookconfiguration actions-runner-controller-validating-webhook-configuration --ignore-not-found

# 3. Forcer reconcile des sources
flux reconcile source helm actions-runner-controller -n flux-system
flux reconcile kustomization arc-release -n flux-system --with-source

# 4. Réinstaller le HelmRelease ARC
flux reconcile helmrelease actions-runner-controller -n arc-system

# 5. Vérifier que les webhooks sont recréés et corrects
echo "=== Vérification des webhooks recréés ==="
kubectl get mutatingwebhookconfigurations | grep actions-runner-controller || echo "❌ Aucun mutating webhook trouvé"
kubectl get validatingwebhookconfigurations | grep actions-runner-controller || echo "❌ Aucun validating webhook trouvé"

echo "=== Reset terminé ==="
