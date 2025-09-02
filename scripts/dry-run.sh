#!/usr/bin/env bash
set -euo pipefail

DIR="${DIR:-apps/whoami}"
KUBECTL="${KUBECTL:-kubectl}"
MODE="${MODE:-server}"   # client|server

usage() { echo "Usage: MODE=server DIR=apps/whoami $0"; }

if [[ "${1:-}" == "--help" ]]; then usage; exit 0; fi

case "${MODE}" in
  client) echo ">> kubectl apply --dry-run=client -k ${DIR}"
          "${KUBECTL}" apply --dry-run=client -k "${DIR}";;
  server) echo ">> kubectl apply --dry-run=server -k ${DIR}"
          "${KUBECTL}" apply --dry-run=server -k "${DIR}";;
  *) echo "MODE must be client|server"; exit 1;;
esac

