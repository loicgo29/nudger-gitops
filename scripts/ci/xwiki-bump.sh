#!/usr/bin/env bash
set -euo pipefail

# --- Variables ----------------------------------------------------
XWIKI_VERSION="${1:-17.4.0}"   # version XWiki à déployer
CLUSTERS_DIR="clusters"

# --- Fonctions utilitaires ----------------------------------------
commit_and_push() {
  local msg="$1"
  git config user.name "nudger-bot"
  git config user.email "bot@logo-solutions.fr"
  git add .
  git commit -m "$msg" || echo "Nothing to commit"
  git push origin HEAD
}

# --- Étape 1 : bump en intégration --------------------------------
echo "➡️ Mise à jour XWiki version ${XWIKI_VERSION} en intégration..."
sed -i "s|image: .*xwiki:.*|image: xwiki:${XWIKI_VERSION}|g" \
  "${CLUSTERS_DIR}/integration/xwiki/kustomization.yaml"

# Vérification syntaxe avec kustomize + kubeconform
echo "🔍 Validation des manifests..."
kustomize build "${CLUSTERS_DIR}/integration/xwiki" | kubeconform -strict

commit_and_push "chore: bump XWiki to ${XWIKI_VERSION} in integration [skip ci]"

# --- Étape 2 : promotion recette (si demandé) ---------------------
if [[ "${PROMOTE:-false}" == "true" ]]; then
  echo "➡️ Promotion XWiki ${XWIKI_VERSION} vers recette..."
  cp "${CLUSTERS_DIR}/integration/xwiki/kustomization.yaml" \
     "${CLUSTERS_DIR}/recette/xwiki/kustomization.yaml"

  commit_and_push "chore: promote XWiki ${XWIKI_VERSION} to recette [skip ci]"
fi

echo "✅ Script terminé."
