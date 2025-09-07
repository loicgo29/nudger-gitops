#!/usr/bin/env bash
set -euo pipefail

KUBECTL="${KUBECTL:-kubectl}"
FLUX="${FLUX:-flux}"
NS="${FLUX_NS:-flux-system}"
GITSRC="${GITSRC:-gitops}"

usage() { echo "Usage: FLUX_NS=flux-system GITSRC=gitops $0"; }

if [[ "${1:-}" == "--help" ]]; then usage; exit 0; fi

echo ">> flux reconcile source git ${GITSRC} -n ${NS}"
"${FLUX}" reconcile source git "${GITSRC}" -n "${NS}"

echo ">> Reconciling all Kustomizations"
"${KUBECTL}" get kustomization -A -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' \
| while read -r ns name; do
  echo " - ${ns}/${name}"
  "${FLUX}" reconcile kustomization "${name}" -n "${ns}" --with-source
done

echo
"${FLUX}" get kustomizations -A

