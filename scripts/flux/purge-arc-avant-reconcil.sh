#!/usr/bin/env bash
set -euo pipefail

echo "=== Purge complète Actions Runner Controller ==="

# 1. Supprimer les anciens webhooks qui pointent vers actions-runner-system/webhook-service
echo "[1] Suppression des WebhookConfigurations obsolètes..."
kubectl get validatingwebhookconfigurations.admissionregistration.k8s.io -o name | grep runner || true
kubectl get mutatingwebhookconfigurations.admissionregistration.k8s.io -o name | grep runner || true

kubectl delete validatingwebhookconfigurations.admissionregistration.k8s.io \
  $(kubectl get validatingwebhookconfigurations.admissionregistration.k8s.io -o name | grep runner | awk -F/ '{print $2}') 2>/dev/null || true

kubectl delete mutatingwebhookconfigurations.admissionregistration.k8s.io \
  $(kubectl get mutatingwebhookconfigurations.admissionregistration.k8s.io -o name | grep runner | awk -F/ '{print $2}') 2>/dev/null || true

# 2. Supprimer l’ancien namespace actions-runner-system (si présent)
echo "[2] Suppression ancien namespace actions-runner-system..."
kubectl delete ns actions-runner-system --ignore-not-found=true

# 3. Supprimer tous les secrets liés à ARC dans arc-system
echo "[3] Purge des secrets dans arc-system..."
kubectl -n arc-system delete secret controller-manager --ignore-not-found=true
kubectl -n arc-system delete secret actions-runner-controller --ignore-not-found=true

# 4. Supprimer les anciens sealedsecrets liés à ARC
echo "[4] Purge des SealedSecrets ARC..."
kubectl -n arc-system delete sealedsecret actions-runner-controller --ignore-not-found=true

# 5. Supprimer l’ancien HelmRelease (si existait ailleurs)
echo "[5] Purge des HelmReleases ARC fantômes..."
kubectl get helmreleases -A | grep actions-runner-controller || true

# 6. Reconcilier les sources et HelmRelease propres
echo "[6] Relance reconcile HelmRelease ARC..."
flux reconcile source helm actions-runner-controller -n flux-system --with-source || true
flux reconcile helmrelease actions-runner-controller -n arc-system --with-source || true

# 7. Reconcilier les runners
echo "[7] Relance reconcile runners recette..."
flux reconcile kustomization arc-runners-recette -n flux-system --with-source || true

echo "=== Purge terminée ==="
