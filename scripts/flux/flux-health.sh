#!/usr/bin/env bash
# flux-health.sh v3 — Audit robuste de FluxCD via kubectl (JSON)
# Dépendances : kubectl, jq. Optionnel : flux (pour 'flux tree')

set -euo pipefail

NS="flux-system"
APP_KS=""
VERBOSE=0
SHOW_TREE=0
EXIT_CODE=0

usage() {
  cat <<'EOF'
Usage: flux-health.sh [-n <namespace>] [-t <kustomization>] [-v] [-h]
  -n  Namespace Flux (default: flux-system)
  -t  Affiche l'arbre de dépendances (flux tree) pour cette Kustomization
  -v  Verbose (events récents des contrôleurs)
  -h  Aide
EOF
}

while getopts ":n:t:vh" opt; do
  case ${opt} in
    n) NS="$OPTARG" ;;
    t) APP_KS="$OPTARG"; SHOW_TREE=1 ;;
    v) VERBOSE=1 ;;
    h) usage; exit 0 ;;
    \?) echo "[ERR] Option invalide: -$OPTARG" >&2; exit 2 ;;
    :)  echo "[ERR] Option -$OPTARG requiert un argument" >&2; exit 2 ;;
  esac
done

need() { command -v "$1" >/dev/null 2>&1 || { echo "[ERR] Manque: $1"; exit 3; }; }
need kubectl; need jq

banner() { printf "\n\033[1;34m== %s ==\033[0m\n" "$*"; }
ok()   { printf "\033[1;32m[OK]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[ERR]\033[0m %s\n" "$*"; EXIT_CODE=1; }

# 0) Contrôleurs Flux (Deployments)
banner "Contrôleurs Flux ($NS)"
DEP_JSON="$(kubectl -n "$NS" get deploy -o json 2>/dev/null || true)"
if [ -z "$DEP_JSON" ] || [ "$(echo "$DEP_JSON" | jq '.items|length')" -eq 0 ]; then
  err "Aucun Deployment trouvé dans $NS (Flux installé ?)"
else
  echo "$DEP_JSON" | jq -r '.items[] | "\(.metadata.name)\tready=\(.status.readyReplicas // 0)/\(.spec.replicas // 0)"'
  NOTREADY=$(echo "$DEP_JSON" | jq -r '.items[] | select((.status.readyReplicas // 0) != (.spec.replicas // 0)) | .metadata.name')
  if [ -n "${NOTREADY:-}" ]; then err "Contrôleurs non Ready: $(echo "$NOTREADY" | tr '\n' ' ')"; else ok "Tous les contrôleurs Flux sont Ready"; fi
  [ "$VERBOSE" -eq 1 ] && kubectl -n "$NS" get events --sort-by=.lastTimestamp | tail -n 30 || true
fi

# 1) Sources Git (GitRepository)
banner "Sources Git (GitRepository)"
SRC_JSON="$(kubectl -n "$NS" get gitrepositories.source.toolkit.fluxcd.io -o json 2>/dev/null || true)"
if [ -z "$SRC_JSON" ] || [ "$(echo "$SRC_JSON" | jq '.items|length')" -eq 0 ]; then
  warn "Aucune source Git dans $NS (OK si vous n'en avez pas)"
else
echo "$SRC_JSON" | jq -r '.items[] |
  [
    .metadata.name,
    ("ready=" + ((.status.conditions[]? | select(.type=="Ready") | .status) // "-")),
    ("rev=" + (.status.artifact.revision // "-")),
    ("msg=" + ((.status.conditions[]? | select(.type=="Ready") | .message) // "-"))
  ] | @tsv'
  BAD=$(echo "$SRC_JSON" | jq -r '.items[] | select(.status.conditions[]? | select(.type=="Ready" and .status!="True")) | .metadata.name')
  [ -n "${BAD:-}" ] && err "Sources Git non Ready: $(echo "$BAD" | tr '\n' ' ')" || ok "Toutes les sources Git sont Ready"
fi

# 2) Kustomizations
banner "Kustomizations"
KS_JSON="$(kubectl get kustomizations.kustomize.toolkit.fluxcd.io -A -o json)"
echo "$KS_JSON" | jq -r '.items[] |
  [
    (.metadata.namespace + "/" + .metadata.name),
    ("suspended=" + (if (.spec.suspend // false) then "true" else "false" end)),
    ("ready=" + ((.status.conditions[]? | select(.type=="Ready") | .status) // "-")),
    ("rev=" + (.status.lastAppliedRevision // "-"))
  ] | @tsv'
  SUSP=$(echo "$KS_JSON" | jq -r '.items[] | select(.spec.suspend==true) | "\(.metadata.namespace)/\(.metadata.name)"')
NOTR=$(echo "$KS_JSON" | jq -r '.items[] | select(.status.conditions[]? | select(.type=="Ready" and .status!="True")) | "\(.metadata.namespace)/\(.metadata.name)"')
[ -n "${SUSP:-}" ] && err "Kustomizations SUSPENDUES: $(echo "$SUSP" | tr '\n' ' ')" || ok "Aucune Kustomization suspendue"
[ -n "${NOTR:-}" ] && err "Kustomizations non Ready: $(echo "$NOTR" | tr '\n' ' ')" || ok "Toutes les Kustomizations sont Ready"

# 3) HelmReleases
banner "HelmReleases"
HR_JSON="$(kubectl get helmreleases.helm.toolkit.fluxcd.io -A -o json 2>/dev/null || true)"
if [ -z "$HR_JSON" ] || [ "$(echo "$HR_JSON" | jq '.items|length')" -eq 0 ]; then
  warn "Pas de HelmRelease trouvée (OK si vous n'utilisez pas Helm via Flux)"
else
  echo "$HR_JSON" | jq -r '.items[] |
  [
    (.metadata.namespace + "/" + .metadata.name),
    ("ready=" + ((.status.conditions[]? | select(.type=="Ready") | .status) // "-")),
    ("msg=" + ((.status.conditions[]? | select(.type=="Ready") | .message) // "-"))
  ] | @tsv'
  HR_BAD=$(echo "$HR_JSON" | jq -r '.items[] | select(.status.conditions[]? | select(.type=="Ready" and .status!="True")) | "\(.metadata.namespace)/\(.metadata.name)"')
  [ -n "${HR_BAD:-}" ] && err "HelmReleases non Ready: $(echo "$HR_BAD" | tr '\n' ' ')" || ok "Toutes les HelmReleases sont Ready"
fi

# 4) Arbre de dépendances (optionnel) avec flux si dispo
if [ "$SHOW_TREE" -eq 1 ] && [ -n "$APP_KS" ]; then
  banner "flux tree — $APP_KS@$NS"
  if command -v flux >/dev/null 2>&1; then
    if flux tree kustomization "$APP_KS" -n "$NS"; then ok "Arbre affiché"; else err "Impossible d'afficher l'arbre"; fi
  else
    warn "'flux' CLI non trouvé — saute l'arbre"
  fi
fi

# 5) Résumé
banner "Résumé"
if [ "$EXIT_CODE" -eq 0 ]; then ok "État Flux global: OK ✅"; else err "État Flux global: PROBLÈMES détectés ❌"; fi
exit "$EXIT_CODE"
