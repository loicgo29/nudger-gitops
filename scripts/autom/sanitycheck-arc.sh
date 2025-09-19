#!/bin/bash
set -euo pipefail

echo "=== Sanity Check ARC (Actions Runner Controller) ==="

# Vérifie les Kustomizations
echo "[1] Vérification des Kustomizations..."
kubectl -n flux-system get kustomization arc-repo arc-release

# Vérifie que le HelmRelease est Ready
echo "[2] Vérification du HelmRelease..."
kubectl -n arc-system get helmrelease actions-runner-controller

# Vérifie que le déploiement et les pods sont bien en place
echo "[3] Vérification du Deployment et Pods..."
kubectl -n arc-system get deploy,pods -o wide

# Vérifie que le secret GitHub App existe
echo "[4] Vérification du Secret GitHub App..."
kubectl -n arc-system get secret controller-manager || echo "❌ Secret manquant"

# Vérifie le certificat TLS du webhook ARC
echo "[5] Vérification du certificat TLS du webhook..."
kubectl -n arc-system get certificate actions-runner-controller-serving-cert || echo "❌ Certificat manquant"

echo "=== Fin du sanity check ==="
