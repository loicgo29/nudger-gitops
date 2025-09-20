#!/bin/bash
set -euo pipefail
echo "=== Reset complet ARC (Actions Runner Controller) ==="

# 0. Corriger le mauvais sourceRef si encore présent
echo "[0] Correction sourceRef gitops -> flux-system"
grep -Rl "name: gitops" ./clusters | xargs -r sed -i 's/name: gitops/name: flux-system/g'

# 1. Supprimer l'HelmRelease ARC
kubectl -n arc-system delete helmrelease actions-runner-controller --ignore-not-found

# 2. Supprimer les webhooks existants
kubectl delete mutatingwebhookconfiguration actions-runner-controller-mutating-webhook-configuration --ignore-not-found
kubectl delete validatingwebhookconfiguration actions-runner-controller-validating-webhook-configuration --ignore-not-found

# 3. Purger l’HelmChart en cache
kubectl -n flux-system delete helmchart arc-system-actions-runner-controller --ignore-not-found || true

# 4. Forcer reconcile du repo et des kustomizations
flux reconcile source git flux-system -n flux-system
flux reconcile kustomization arc-release -n flux-system
flux reconcile kustomization arc-repo -n flux-system

# 5. Réinstaller le HelmRelease ARC
flux reconcile helmrelease actions-runner-controller -n arc-system

# 6. Vérifier que les webhooks sont recréés et corrects
echo "=== Vérification des webhooks recréés ==="
kubectl get mutatingwebhookconfigurations | grep actions-runner-controller || echo "❌ Aucun mutating webhook trouvé"
kubectl get validatingwebhookconfigurations | grep actions-runner-controller || echo "❌ Aucun validating webhook trouvé"

echo "=== Reset terminé ==="
