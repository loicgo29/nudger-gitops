#!/usr/bin/env bash
set -euo pipefail

# 🔧 Paramètres
NAME="${1:-}"
[[ -z "$NAME" ]] && { echo "❌ Usage: $0 <release-name>"; exit 1; }

# 📁 Chemins
SRC="infra/observability/overlays/lab/helmrelease-${NAME}.yaml"
DEST_DIR="infra/observability/releases/${NAME}"
DEST_FILE="${DEST_DIR}/helmrelease.yaml"
DEST_KUSTOM="${DEST_DIR}/kustomization.yaml"

# ✅ Étapes
echo "📦 Refactor: $SRC → $DEST_FILE"

# 1. Créer le dossier cible
mkdir -p "$DEST_DIR"

# 2. Déplacer le fichier
if [[ -f "$SRC" ]]; then
  mv "$SRC" "$DEST_FILE"
else
  echo "⚠️  Fichier introuvable: $SRC"
  exit 2
fi

# 3. Créer le Kustomization de wrapper
cat <<EOF > "$DEST_KUSTOM"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - helmrelease.yaml
EOF

# 4. Patch tous les kustomization.yaml du repo
find . -name 'kustomization.yaml' \
  -exec sed -i "s|../../observability/releases/helmrelease-${NAME}.yaml|../../observability/releases/${NAME}|g" {} +

echo "✅ HelmRelease $NAME mutualisé dans $DEST_DIR"
