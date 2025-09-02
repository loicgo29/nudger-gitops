#!/usr/bin/env bash
set -euo pipefail

GH="${GH:-gh}"
WF_FILE="${WF_FILE:-.github/workflows/auto-pr-from-flux.yml}"
HEAD="${AUTO_UPDATE_BRANCH:-flux-imageupdates}"

usage() { echo "Usage: AUTO_UPDATE_BRANCH=flux-imageupdates WF_FILE=.github/workflows/auto-pr-from-flux.yml $0"; }

if [[ "${1:-}" == "--help" ]]; then usage; exit 0; fi
if ! command -v "${GH}" >/dev/null 2>&1; then
  echo "'gh' non trouvé. Installe GitHub CLI."
  exit 1
fi

WF_NAME="$(basename "${WF_FILE}")"
echo ">> gh workflow run ${WF_NAME} -f head_branch=${HEAD}"
"${GH}" workflow run "${WF_NAME}" -f "head_branch=${HEAD}" || true
echo ">> Consulte ensuite: gh run list --limit 5"

