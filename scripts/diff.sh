#!/usr/bin/env bash
set -euo pipefail

DIR="${DIR:-apps/whoami}"   # dossier kustomize
KUBECTL="${KUBECTL:-kubectl}"

usage() { echo "Usage: DIR=apps/whoami $0"; }

if [[ "${1:-}" == "--help" ]]; then usage; exit 0; fi

echo ">> kubectl diff -k ${DIR}"
"${KUBECTL}" diff -k "${DIR}" || true

