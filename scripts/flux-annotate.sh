#!/usr/bin/env bash
set -euo pipefail

KUBECTL="${KUBECTL:-kubectl}"
NS="${FLUX_NS:-flux-system}"
AUTONAME="${AUTONAME:-whoami-update}"

usage() { echo "Usage: FLUX_NS=flux-system AUTONAME=whoami-update $0"; }

if [[ "${1:-}" == "--help" ]]; then usage; exit 0; fi

echo ">> Annotating ImageUpdateAutomation ${AUTONAME} in ${NS}"
"${KUBECTL}" -n "${NS}" annotate imageupdateautomation "${AUTONAME}" \
  "reconcile.fluxcd.io/requestedAt=$(date +%s)" --overwrite

