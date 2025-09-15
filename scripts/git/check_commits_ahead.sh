#!/usr/bin/env bash
set -euo pipefail

# ---- Config ----
REMOTE="${REMOTE:-origin}"
BASE_BRANCH="${BASE_BRANCH:-main}"   # override possible via env
# ----------------

# Assure que l'historique est complet (utile sur CI avec fetch-depth:1)
git remote set-url "$REMOTE" "$(git remote get-url "$REMOTE")" >/dev/null 2>&1 || true
git fetch --no-tags --prune "$REMOTE" \
  "+refs/heads/*:refs/remotes/$REMOTE/*" \
  "+HEAD:refs/remotes/$REMOTE/HEAD" >/dev/null

# HEAD peut être "detached" en CI : on compare la révision courante à REMOTE/BASE_BRANCH
if ! git rev-parse --verify "refs/remotes/$REMOTE/$BASE_BRANCH" >/dev/null 2>&1; then
  echo "Erreur: branche de base introuvable: $REMOTE/$BASE_BRANCH" >&2
  exit 2
fi

AHEAD_COUNT="$(git rev-list --count "refs/remotes/$REMOTE/$BASE_BRANCH..HEAD")"
echo "Commits ahead ($REMOTE/$BASE_BRANCH..HEAD) = $AHEAD_COUNT"

# Expose aussi en sortie GitHub Actions si disponible
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "commits_ahead=$AHEAD_COUNT"
    echo "base_ref=$REMOTE/$BASE_BRANCH"
  } >> "$GITHUB_OUTPUT"
fi

# Code de sortie :
#  - 0 si au moins 1 commit (il y a quelque chose à PR)
#  - 1 si rien à PR
if [[ "$AHEAD_COUNT" -gt 0 ]]; then
  exit 0
else
  exit 1
fi

