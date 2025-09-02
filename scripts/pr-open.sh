#!/usr/bin/env bash
set -euo pipefail

GH="${GH:-gh}"
BASE="${BASE_BRANCH:-main}"
HEAD="${AUTO_UPDATE_BRANCH:-flux-imageupdates}"

usage() { echo "Usage: BASE_BRANCH=main AUTO_UPDATE_BRANCH=flux-imageupdates $0"; }

if [[ "${1:-}" == "--help" ]]; then usage; exit 0; fi

if ! command -v "${GH}" >/dev/null 2>&1; then
  echo "'gh' non trouvé. Installe GitHub CLI."
  exit 1
fi

git fetch origin
AHEAD=$(git rev-list --count "origin/${BASE}..origin/${HEAD}" || echo 0)
echo "Commits ahead origin/${BASE}..origin/${HEAD}: ${AHEAD}"
if [[ "${AHEAD}" -eq 0 ]]; then
  echo "Aucun commit en avance → rien à PR."
  exit 0
fi

# PR existante ?
EXISTS=$("${GH}" pr list --head "${HEAD}" --base "${BASE}" --state all --json number,state -q '.[0].number' || true)
if [[ -n "${EXISTS}" ]]; then
  STATE=$("${GH}" pr view "${EXISTS}" --json state -q .state)
  [[ "${STATE}" == "CLOSED" ]] && "${GH}" pr reopen "${EXISTS}"
  "${GH}" pr view "${EXISTS}" --json url -q .url
else
  "${GH}" pr create --head "${HEAD}" --base "${BASE}" \
    --title "chore(images): updates from Flux" \
    --body "PR auto depuis \`${HEAD}\`"
  "${GH}" pr list --head "${HEAD}" --base "${BASE}" --state open --json url -q '.[0].url'
fi

