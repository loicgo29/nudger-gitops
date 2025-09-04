#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/fluxlog.sh [APP_NAME] [SINCE] [KEYWORDS]
# Exemples:
#   ./scripts/fluxlog.sh
#   ./scripts/fluxlog.sh whoami 30m
#   ./scripts/fluxlog.sh whoami 30m "error longhorn"
#
# Variables:
#   FLUX_NS  : namespace Flux (defaut: flux-system)

NS="${FLUX_NS:-flux-system}"
APP="${1:-whoami}"
SINCE="${2:-15m}"
KW_RAW="${3:-}"   # mots-clés personnalisés, ex: "error longhorn" ou "error|longhorn"

# Si des mots-clés sont fournis, on remplace les espaces par des |
if [[ -n "${KW_RAW}" ]]; then
  KW_REGEX="$(echo "${KW_RAW}" | sed -E 's/[[:space:]]+/\|/g')"
else
  # filtre par défaut (inclut l'app + termes flux/erreurs usuels)
  KW_REGEX="${APP}|reconcil|error|failed|degrad|commit|push|image|policy|apply|health|alert"
fi

echo "== Flux log/search =="
echo "NS=${NS}  APP=${APP}  SINCE=${SINCE}"
echo "FILTER=${KW_REGEX}"
echo

section() { echo; echo "## $*"; }

filter_or_cat() {
  # lit stdin ; si KW_REGEX est vide => cat, sinon grep -Ei
  if [[ -n "${KW_REGEX}" ]]; then
    grep -Ei -- "${KW_REGEX}" || true
  else
    cat
  fi
}

log_if_exists() {
  local d="$1"
  if kubectl -n "$NS" get deploy "$d" >/dev/null 2>&1; then
    section "Logs ($d) — since ${SINCE}"
    kubectl -n "$NS" logs deploy/"$d" --since="${SINCE}" --tail=1000 | filter_or_cat
  fi
}

# --- Résumé des CRs image* et kustomizations (filtrés par KW si fourni)
section "Image resources (ImageRepository / ImagePolicy / ImageUpdateAutomation)"
kubectl -n "$NS" get imagerepository,imagepolicy,imageupdateautomation 2>/dev/null | filter_or_cat

section "Kustomizations"
kubectl -n "$NS" get kustomizations -o wide 2>/dev/null | filter_or_cat

section "Dernière résolution ImagePolicy.latestImage"
kubectl -n "$NS" get imagepolicy -o yaml 2>/dev/null \
  | yq -r '.items[] | [.metadata.name, .status.latestImage] | @tsv' \
  | filter_or_cat

section "ImageRepository dernier scan (top 10 tags vus)"
kubectl -n "$NS" get imagerepository -o yaml 2>/dev/null \
  | yq -r '.items[] | .metadata.name as $n | .status.lastScanResult.latestTags[0:10][] | "\($n)\t"+.' \
  | filter_or_cat

# --- Événements utiles
section "Events (Flux NS) — derniers 200 (filtrés)"
kubectl -n "$NS" get events --sort-by=.lastTimestamp 2>/dev/null | tail -n 200 | filter_or_cat

# --- Logs des contrôleurs Flux
log_if_exists source-controller
log_if_exists kustomize-controller
log_if_exists helm-controller
log_if_exists image-reflector-controller
log_if_exists image-automation-controller
log_if_exists notification-controller

# --- Détails Kustomization 'apps' si elle existe
if kubectl -n "$NS" get kustomization apps >/dev/null 2>&1; then
  section "Kustomization apps — Conditions"
  kubectl -n "$NS" get kustomization apps -o yaml \
    | yq '.status.conditions' | filter_or_cat

  section "Kustomization apps — Events"
  kubectl -n "$NS" describe kustomization apps 2>/dev/null \
    | sed -n '/Events/,$p' | filter_or_cat
fi

echo
echo "Tips:"
echo "  - Forcer un cycle: "
echo "      flux reconcile source git gitops -n ${NS}"
echo "      flux reconcile kustomization apps -n ${NS} --with-source"
echo "      flux reconcile image repository <name> -n ${NS}"
echo "      flux reconcile image update <name> -n ${NS}"
echo "  - Exemples de recherche:"
echo "      ./scripts/fluxlog.sh '' 30m 'error longhorn'"
echo "      ./scripts/fluxlog.sh whoami 15m 'failed|degraded'"
echo
echo "Done."
