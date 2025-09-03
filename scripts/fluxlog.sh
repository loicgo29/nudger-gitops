#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/flux-recon-check.sh [APP_NAME] [SINCE]
# Exemples:
#   ./scripts/flux-recon-check.sh                # APP=whoami, SINCE=15m
#   ./scripts/flux-recon-check.sh whoami 30m
#   FLUX_NS=flux-system ./scripts/flux-recon-check.sh ui 10m
#
# Variables:
#   FLUX_NS  : namespace Flux (defaut: flux-system)

NS="${FLUX_NS:-flux-system}"
APP="${1:-whoami}"
SINCE="${2:-15m}"

echo "== Flux reconciliation check =="
echo "NS=${NS}  APP=${APP}  SINCE=${SINCE}"
echo

section() { echo; echo "## $*"; }
log_if_exists() {
  local d="$1"
  if kubectl -n "$NS" get deploy "$d" >/dev/null 2>&1; then
    section "Logs ($d) — since ${SINCE} (grep: ${APP}|reconcile|error|commit)"
    # On filtre un peu pour aller à l’essentiel ; enlève le grep si tu veux tout voir
    kubectl -n "$NS" logs deploy/"$d" --since="$SINCE" --tail=1000 \
      | grep -Ei "${APP}|reconcil|error|failed|commit|push|image|policy" || true
  fi
}

# --- Résumé des CRs image* et kustomizations
section "Image resources (ImageRepository / ImagePolicy / ImageUpdateAutomation)"
kubectl -n "$NS" get imagerepository,imagepolicy,imageupdateautomation 2>/dev/null | (grep -E "$APP|NAME" || true)

section "Kustomizations"
kubectl -n "$NS" get kustomizations -o wide 2>/dev/null | (grep -E "$APP|apps|NAME" || true)

section "Dernière résolution ImagePolicy.latestImage"
kubectl -n "$NS" get imagepolicy -o yaml 2>/dev/null \
  | yq -r '.items[] | [.metadata.name, .status.latestImage] | @tsv' \
  | (grep -E "$APP" || true)

section "ImageRepository dernier scan (top 10 tags vus)"
kubectl -n "$NS" get imagerepository -o yaml 2>/dev/null \
  | yq -r '.items[] | select(.metadata.name | test("'"$APP"'")) | .status.lastScanResult.latestTags[0:10][]' || true

# --- Événements utiles
section "Events (Flux NS) — derniers 50"
kubectl -n "$NS" get events --sort-by=.lastTimestamp | tail -n 50 || true

# --- Logs des contrôleurs Flux
log_if_exists source-controller
log_if_exists kustomize-controller
log_if_exists helm-controller
log_if_exists image-reflector-controller
log_if_exists image-automation-controller
log_if_exists notification-controller

# --- Détails Kustomization 'apps' si elle existe (utile pour voir les erreurs d'applique)
if kubectl -n "$NS" get kustomization apps >/dev/null 2>&1; then
  section "Kustomization apps — Conditions"
  kubectl -n "$NS" get kustomization apps -o yaml \
    | yq '.status.conditions' || true

  section "Kustomization apps — Events"
  kubectl -n "$NS" describe kustomization apps | sed -n '/Events/,$p' || true
fi

echo
echo "Tip:"
echo "  - Forcer un cycle: "
echo "      flux reconcile source git gitops -n ${NS}"
echo "      flux reconcile image repository whoami -n ${NS}"
echo "      kubectl -n ${NS} annotate imagepolicy whoami reconcile.fluxcd.io/requestedAt=\"$(date -u +%FT%TZ)\" --overwrite"
echo "      flux reconcile image update whoami-update -n ${NS}"
echo "      flux reconcile kustomization apps -n ${NS} --with-source"
echo
echo "Done."
