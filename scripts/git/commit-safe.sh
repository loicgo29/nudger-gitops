#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'EOF'
commit-safe.sh — Commit guard avec convention de message

Usage:
  scripts/git/commit-safe.sh "<type>(scope): message"
  scripts/git/commit-safe.sh -h|--help

Règles:
  - Vérifie qu'il y a bien des modifications à committer
  - Valide le format de message:
      (BREAKING|feat|fix|chore|docs|refactor|test|perf)(optional-scope): message

Exemples:
  scripts/git/commit-safe.sh "feat(whoami): expose ingress nodeport"
  scripts/git/commit-safe.sh "fix: corrige readiness probe"
  scripts/git/commit-safe.sh "docs: ajoute README Commandes"
EOF
}

# Aide
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  show_help
  exit 0
fi

branch=$(git rev-parse --abbrev-ref HEAD)

# Vérifie s'il y a des modifs à commit
if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
  echo "📌 Modifs détectées :"
  git status -s
else
  echo "✅ Rien à commit"
  exit 0
fi

# Vérifie le message
if [ $# -eq 0 ]; then
  echo "❌ Fournis un message de commit (ex: feat: ajoute script gcp)"
  echo "   Utilise -h pour l'aide."
  exit 1
fi

msg="$*"

# Vérifie la convention (feat|fix|chore|docs|refactor|test|perf|BREAKING)
if ! [[ "$msg" =~ ^(BREAKING|feat|fix|chore|docs|refactor|test|perf)(\([a-z0-9_-]+\))?:\ .+ ]]; then
  echo "❌ Message invalide."
  show_help
  exit 1
fi

# Etape importante : propose de sélectionner les fichiers
echo "➡️ Fichiers modifiés :"
git status -s

echo
echo "👉 Sélectionne les fichiers à ajouter (ou 'a' pour tous) :"
read -r -p "> " files

if [[ "$files" == "a" ]]; then
  git add -p
else
  git add $files
fi

# Vérifie qu’il y a bien des fichiers stagés
if git diff --cached --quiet; then
  echo "❌ Aucun fichier stagé. Abort."
  exit 1
fi

# Commit
echo "➡️ Commit sur '$branch' avec : \"$msg\""
git commit -m "$msg"

# Push (sans rebase forcé)
echo "🚀 Push"
git push origin "$branch"
