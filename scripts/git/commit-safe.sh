#!/bin/bash
set -euo pipefail

# Vérifier qu'on est bien dans un repo git
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  echo "❌ Pas dans un repo git"
  exit 1
fi

# Ajouter tous les changements (y compris fichiers non suivis)
git add -A

# Générer un message automatique avec timestamp
stamp=$(date +%Y%m%d-%H%M%S)
msg="chore: auto-commit [$stamp]"

# Commit
git commit -m "$msg" || echo "⚠️ Rien à committer"

# Push
branch=$(git rev-parse --abbrev-ref HEAD)
git push origin "$branch"

echo "🚀 $msg poussé sur $branch"
