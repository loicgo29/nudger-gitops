#!/usr/bin/env bash
set -euo pipefail

FLUX="${FLUX:-flux}"
NS="${FLUX_NS:-flux-system}"
KZ="${KZ:-apps}"   # nom de la Kustomization (CR Flux)

usage() { echo "Usage: FLUX_NS=flux-system KZ=apps $0"; }

if [[ "${1:-}" == "--help" ]]; then usage; exit 0; fi

echo ">> flux build kustomization ${KZ} -n ${NS}"

echo "${FLUX} build kustomization ${KZ} -n ${NS}"
kustomize build ./apps/whoami
kustomize build ./apps/whoami | kubectl apply --dry-run=server -f -


