#!/usr/bin/env bash
set -euo pipefail

XWIKI_VERSION="${1:-17.4.0}"

# --- Étape 1 : bump image dans le StatefulSet ---
echo "➡️ Mise à jour XWiki version ${XWIKI_VERSION}..."
sed -i "s|image: xwiki:.*|image: xwiki:${XWIKI_VERSION}-mysql-tomcat|g" apps/xwiki/base/xwiki-statefulset.yaml

# --- Étape 2 : validation kustomize ---
echo "🔍 Validation des manifests..."
kustomize build apps/xwiki/overlays/integration | kubeconform -strict

# --- Étape 3 : commit & push ---
git config user.name "nudger-bot"
git config user.email "bot@logo-solutions.fr"
git add apps/xwiki/base/xwiki-statefulset.yaml
git commit -m "chore: bump XWiki to ${XWIKI_VERSION} in integration [skip ci]" || echo "Nothing to commit"
git push origin HEAD

echo "✅ Bump terminé."
