#!/usr/bin/env bash
set -euo pipefail

# Branche courante
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# On refuse si déjà sur main
if [ "$CURRENT_BRANCH" = "main" ]; then
  echo "❌ Tu es déjà sur main, rien à merger."
  exit 1
fi

echo "➡️ Fusion de $CURRENT_BRANCH dans main ..."

# Se mettre sur main et update
git checkout main
git pull --ff-only origin main

# Merger la branche courante
git merge --no-ff "$CURRENT_BRANCH"

# Push vers le remote
git push origin main

# Supprimer la branche locale
git branch -d "$CURRENT_BRANCH"

echo "✅ Branche $CURRENT_BRANCH mergée dans main et supprimée."
