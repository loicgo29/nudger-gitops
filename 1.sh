#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

echo "➡️ Mise à niveau du cluster LAB depuis RECETTE..."

# --- Clusters ---------------------------------------------------------------
echo "📂 Copie des kustomizations manquantes dans clusters/lab/"
cp clusters/recette/xwiki.kustomization.yaml clusters/lab/ || true
cp clusters/recette/actions-runner-controller.kustomization.yaml clusters/lab/ || true
cp clusters/recette/cert-manager.kustomization.yaml clusters/lab/ || true
cp clusters/recette/cert-manager-issuers.kustomization.yaml clusters/lab/ || true
cp clusters/recette/kyverno-policies.kustomization.yaml clusters/lab/ || true
cp clusters/recette/ci-runner-sa.yaml clusters/lab/ || true

mkdir -p clusters/lab/rbac
cp clusters/recette/rbac/ci-runner.yaml clusters/lab/rbac/ || true

# --- Apps -------------------------------------------------------------------
echo "📂 Création de l’overlay lab pour XWiki"
mkdir -p apps/xwiki/overlays/lab
cp apps/xwiki/overlays/recette/* apps/xwiki/overlays/lab/ || true
# FIXME: Adapter namespace, ressources CPU/mémoire, PVC taille

# --- Infra ------------------------------------------------------------------
echo "📂 Création des runners lab (vide)"
mkdir -p infra/action-runner-controller/runners/lab
cat > infra/action-runner-controller/runners/lab/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources: []
# FIXME: Ajouter un RunnerDeployment si besoin
EOF

# --- Root kustomization -----------------------------------------------------
echo "📂 Vérifie clusters/lab/lab-root.kustomization.yaml"
echo "# 👉 Ajoute les entrées manquantes (xwiki, cert-manager, etc.) à resources[]"

echo "✅ Structure LAB alignée avec RECETTE (reste à adapter namespaces/ressources)."
