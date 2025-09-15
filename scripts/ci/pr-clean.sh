#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-flux-imageupdates-}"

usage() { echo "Usage: PREFIX=flux-imageupdates- $0"; }

if [[ "${1:-}" == "--help" ]]; then usage; exit 0; fi

git fetch origin
mapfile -t BRANCHES < <(git branch -r | sed 's|^\s*origin/||' | grep "^${PREFIX}" || true)
if [[ ${#BRANCHES[@]} -eq 0 ]]; then
  echo "Aucune branche à supprimer avec le préfixe '${PREFIX}'."
  exit 0
fi

for b in "${BRANCHES[@]}"; do
  echo "Deleting remote branch: ${b}"
  git push origin ":${b}"
done

