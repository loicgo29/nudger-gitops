#!/usr/bin/env bash
set -euo pipefail

echo "=== Comparaison ARC : état actuel vs état cible ==="

echo ""
echo "[1] Vérification des Kustomizations (arc-repo / arc-release)"
kubectl -n flux-system get kustomizations.kustomize.toolkit.fluxcd.io \
  | grep arc || echo "❌ Aucun arc-* trouvé"

echo ""
echo "[2] SourceRef et namespace utilisés"
for ks in arc-repo arc-release; do
  echo "--- $ks ---"
  kubectl -n flux-system get kustomization $ks -o yaml \
    | grep -E "path:|namespace:|name:|kind:" || true
done

echo ""
echo "[3] HelmReleases existants"
kubectl get helmreleases.helm.toolkit.fluxcd.io -A \
  | grep actions-runner-controller || echo "❌ Aucun HelmRelease ARC trouvé"

echo ""
echo "[4] SealedSecrets liés à ARC"
kubectl get sealedsecrets.bitnami.com -A \
  | grep actions-runner-controller || echo "❌ Aucun SealedSecret ARC trouvé"

echo ""
echo "[5] Services webhook en place"
kubectl get svc -A \
  | grep actions-runner-controller-webhook || echo "❌ Aucun service webhook ARC trouvé"

echo ""
echo "[6] Pods actuels"
kubectl get pods -A \
  | grep actions-runner-controller || echo "❌ Aucun pod ARC trouvé"

echo ""
echo "=== Résumé attendu (solution cible) ==="
cat <<EOF
✅ Namespace attendu : actions-runner-system
✅ HelmRelease : actions-runner-controller (dans actions-runner-system)
✅ SealedSecret : actions-runner-controller (dans actions-runner-system)
✅ Service : actions-runner-controller-webhook (dans actions-runner-system)
✅ Pods : actions-runner-controller-* (dans actions-runner-system)

❌ Tout résidu 'arc-system' doit disparaître
EOF
