#!/usr/bin/env bash
set -euo pipefail

KUBECTL="${KUBECTL:-kubectl}"
FLUX="${FLUX:-flux}"
NS="${FLUX_NS:-flux-system}"
GITSRC="${GITSRC:-gitops}"
TIMEOUT="${TIMEOUT:-2m}"

usage() {
  echo "Usage:"
  echo "  FLUX_NS=flux-system GITSRC=gitops TIMEOUT=2m $0"
}
[[ "${1:-}" == "--help" ]] && { usage; exit 0; }

echo ">> Reconcile Git source: ${GITSRC} (ns: ${NS})"
"${FLUX}" reconcile source git "${GITSRC}" -n "${NS}" --timeout="${TIMEOUT}" || true

echo ">> Wait Ready on GitRepository/${GITSRC}"
${KUBECTL} -n "${NS}" wait --for=condition=Ready "gitrepositories.source.toolkit.fluxcd.io/${GITSRC}" --timeout="${TIMEOUT}" || true

echo ">> Reconcile ALL HelmRepository sources first (to refresh chart indexes)"
${KUBECTL} -n "${NS}" get helmrepository.source.toolkit.fluxcd.io -o name 2>/dev/null \
| while read -r hr; do
  name="${hr##*/}"
  echo " - ${NS}/${name}"
  ${FLUX} reconcile source helm "${name}" -n "${NS}" --timeout="${TIMEOUT}" || true
done

echo ">> Reconcile ALL GitRepository secondary sources (besides ${GITSRC})"
${KUBECTL} -n "${NS}" get gitrepository.source.toolkit.fluxcd.io -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null \
| grep -v -E "^${GITSRC}$" | while read -r gr; do
  echo " - ${NS}/${gr}"
  ${FLUX} reconcile source git "${gr}" -n "${NS}" --timeout="${TIMEOUT}" || true
done

echo ">> Reconcile all Kustomizations (with-source)"
${KUBECTL} get kustomization.kustomize.toolkit.fluxcd.io -A -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' \
| while read -r ns name; do
  echo " - ${ns}/${name}"
  ${FLUX} reconcile kustomization "${name}" -n "${ns}" --with-source --timeout="${TIMEOUT}" || true
done

echo ">> (Optional) Reconcile HelmReleases explicitly (usually not needed)"
${KUBECTL} get helmrelease.helm.toolkit.fluxcd.io -A -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' 2>/dev/null \
| while read -r ns name; do
  echo " - ${ns}/${name}"
  ${FLUX} reconcile helmrelease "${name}" -n "${ns}" --with-source --timeout="${TIMEOUT}" || true
done

echo
echo "== Summary =="
${FLUX} get sources all -A || true
${FLUX} get kustomizations -A || true
${FLUX} get helmreleases -A || true

echo
echo "== Recent Flux errors (30m) =="
${FLUX} logs -A --since=30m | egrep -i "fail|error|refused|timeout" || true
