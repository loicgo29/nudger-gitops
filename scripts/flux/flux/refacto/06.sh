#!/usr/bin/env bash
set -euo pipefail

echo "🔧 [1/3] Création du dossier centralisé"
mkdir -p infra/observability/releases

echo "🚚 [2/3] Déplacement du HelmRelease"
mv infra/observability/overlays/lab/helmrelease-kube-prometheus-stack.yaml \
   infra/observability/releases/helmrelease-kube-prometheus-stack.yaml

echo "🩹 [3/3] Correction des chemins dans tous les kustomization.yaml"
grep -rl 'helmrelease-kube-prometheus-stack.yaml' . \
  | grep kustomization.yaml \
  | xargs sed -i 's|\.\./\.\./observability/overlays/lab/helmrelease-kube-prometheus-stack.yaml|../../observability/releases/helmrelease-kube-prometheus-stack.yaml|g'

echo "✅ Terminé : chemins corrigés"
