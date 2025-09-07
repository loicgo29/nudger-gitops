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

Astuce:
  Scope valide: lettres/chiffres/_/-
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

# Commit et push
echo "➡️ Commit sur '$branch' avec : \"$msg\""
git add -A
git commit -m "$msg" -n
# ... après le commit, juste avant le push :
echo "🔄 Sync avec origin/main (fetch + rebase autostash)"
git fetch origin
git rebase --autostash origin/main

echo "🚀 Push"
git push -u origin "$branch"
