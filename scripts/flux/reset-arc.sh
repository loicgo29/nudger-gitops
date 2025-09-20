#!/bin/bash
set -euo pipefail
echo "=== Reset complet ARC (Actions Runner Controller) ==="

# 0. Correction sourceRef si besoin (gitops -> flux-system)
echo "[0] Vérifie sourceRef..."
sed -i 's/name: gitops/name: flux-system/g' clusters/*/arc-*.kustomization.yaml || true

# 1. Supprimer HelmRelease ARC
echo "[1] Suppression HelmRelease..."
kubectl -n arc-system delete helmrelease actions-runner-controller --ignore-not-found

# 2. Supprimer HelmChart cache
echo "[2] Suppression HelmChart cache..."
kubectl -n flux-system delete helmchart arc-system-actions-runner-controller --ignore-not-found

# 3. Supprimer les webhooks existants
echo "[3] Suppression Webhooks..."
kubectl delete mutatingwebhookconfiguration actions-runner-controller-mutating-webhook-configuration --ignore-not-found
kubectl delete validatingwebhookconfiguration actions-runner-controller-validating-webhook-configuration --ignore-not-found

# 4. Reconcile du HelmRepository ARC
echo "[4] Reconcile HelmRepository..."
flux reconcile source helm actions-runner-controller -n flux-system

# 5. Reconcile des Kustomizations ARC (repo + release)
echo "[5] Reconcile arc-repo & arc-release..."
flux reconcile kustomization arc-repo -n flux-system
flux reconcile kustomization arc-release -n flux-system

# 6. Vérification des ressources ARC
echo "[6] Vérification..."
kubectl -n arc-system get helmreleases | grep actions-runner-controller || echo "❌ HelmRelease absent"
kubectl -n flux-system get helmcharts | grep arc-system-actions-runner-controller || echo "❌ HelmChart absent"
kubectl get mutatingwebhookconfigurations | grep actions-runner-controller || echo "❌ Aucun mutating webhook trouvé"
kubectl get validatingwebhookconfigurations | grep actions-runner-controller || echo "❌ Aucun validating webhook trouvé"

echo "=== Reset terminé ==="
