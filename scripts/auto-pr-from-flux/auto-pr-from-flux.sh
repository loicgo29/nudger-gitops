#!/usr/bin/env bash
# -------------------------------------------------------------
# Script auto-pr-from-flux.sh
# Objectif : quand Flux pousse des updates dans flux-imageupdates,
# créer une branche unique et ouvrir une PR vers main.
# -------------------------------------------------------------
set -euo pipefail

# Variables héritées de GitHub Actions
BASE_BRANCH="${BASE_BRANCH:-main}"
HEAD_BRANCH=""

# --- Détermination de la branche source ---
if [ "${GITHUB_EVENT_NAME:-}" = "workflow_dispatch" ] && [ -n "${GITHUB_EVENT_INPUTS_HEAD_BRANCH:-}" ]; then
  HEAD_BRANCH="${GITHUB_EVENT_INPUTS_HEAD_BRANCH}"
else
  HEAD_BRANCH="${GITHUB_REF_NAME:-flux-imageupdates}"
fi
echo "[INFO] HEAD_BRANCH=$HEAD_BRANCH"
echo "[INFO] BASE_BRANCH=$BASE_BRANCH"

# --- Récupération des refs ---
git fetch origin "+refs/heads/*:refs/remotes/origin/*"
echo "BASE=origin/${BASE_BRANCH}  HEAD=origin/${HEAD_BRANCH}"
echo "BASE SHA: $(git rev-parse origin/${BASE_BRANCH})"
echo "HEAD SHA: $(git rev-parse origin/${HEAD_BRANCH} || echo 'N/A')"

# --- Vérifie si HEAD est en avance sur BASE ---
if ! git rev-parse --verify "origin/${HEAD_BRANCH}" >/dev/null 2>&1; then
  echo "[INFO] La branche origin/${HEAD_BRANCH} n'existe pas. Fin."
  exit 0
fi

AHEAD=$(git rev-list --count "origin/${BASE_BRANCH}..origin/${HEAD_BRANCH}")
echo "[INFO] Commits ahead = ${AHEAD}"
if [ "$AHEAD" -le 0 ]; then
  echo "[INFO] Pas de commit à intégrer. Fin."
  exit 0
fi

# --- Crée une branche unique pour la PR ---
SRC_SHA="$(git rev-parse origin/${HEAD_BRANCH})"
SHORT_SHA="${SRC_SHA:0:7}"
STAMP="$(date +%Y%m%d-%H%M%S)"
NEW_BRANCH="${HEAD_BRANCH}-${SHORT_SHA}-${STAMP}"

git switch --detach "origin/${HEAD_BRANCH}"
git checkout -b "${NEW_BRANCH}"
git push origin "${NEW_BRANCH}:${NEW_BRANCH}"
echo "[INFO] Branche ${NEW_BRANCH} créée et poussée."

# --- Vérifie/Crée les labels nécessaires ---
if command -v gh >/dev/null 2>&1; then
  gh label create flux --color FFD700 --description "Flux automation" \
    || gh label edit flux --color FFD700 --description "Flux automation"
  gh label create automated-pr --color 1D76DB --description "Created by automation" \
    || gh label edit automated-pr --color 1D76DB --description "Created by automation"
else
  echo "[WARN] GitHub CLI (gh) non dispo, impossible de créer/mettre à jour les labels."
fi

# --- Crée la PR ---
if command -v gh >/dev/null 2>&1; then
  gh pr create \
    --head "${NEW_BRANCH}" \
    --base "${BASE_BRANCH}" \
    --title "chore(images): Flux updates (${NEW_BRANCH})" \
    --body "PR auto générée depuis \`${NEW_BRANCH}\` (bump d’images via Flux)." \
    --label flux --label automated-pr
  gh pr list --head "${NEW_BRANCH}" --base "${BASE_BRANCH}" --state open \
    --json number,url -q '.[0] | "PR #"+(.number|tostring)+" → "+.url'
else
  echo "[WARN] GitHub CLI (gh) non dispo, PR non créée automatiquement."
fi
