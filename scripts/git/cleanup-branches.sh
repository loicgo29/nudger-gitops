#!/usr/bin/env bash
# cleanup-branches.sh — Nettoyage de branches (local + remote)
# - Supprime (ou liste) les branches mergées dans une base (def: origin/main)
# - Option pour purge distante
# - Liste blanche configurable (protège flux-imageupdates)
# - Dry-run par défaut ; --apply pour agir
# - NEW: --pr-force + --pr-pattern : supprime les branches "PR" sans PR ouverte (via gh si dispo)

set -euo pipefail

# ----------------------- Defaults -----------------------
BASE_REF="origin/main"
KEEP_REGEX='^(main|develop|flux-imageupdates|release/.*|hotfix/.*)$'
DO_APPLY=0
DO_REMOTE=0
INACTIVE_DAYS=0   # 0 = off
PR_FORCE=0
PR_PATTERN='^(chore/|feat/|fix/|docs/)'
GIT=${GIT:-git}

# ----------------------- Helpers ------------------------
log()  { printf "\033[1;34m[clean]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[warn]\033[0m %s\n" "$*\n"; }
die()  { printf "\033[1;31m[err]\033[0m %s\n" "$*\n"; exit 1; }

usage() {
  cat <<EOF
Usage: $0 [options]
  --apply                 Applique (sinon dry-run)
  --dry-run               Force le dry-run
  --remote                Supprime aussi les branches distantes
  --base <ref>            Base de comparaison (def: ${BASE_REF})
  --keep <regex>          Liste blanche (def: ${KEEP_REGEX})
  --inactive <days>       Liste branches inactives > days (info)
  --pr-force              Force-delete des branches PR sans PR ouverte
  --pr-pattern <regex>    Regex des branches PR (def: ${PR_PATTERN})
  -h|--help               Aide

Exemples :
  $0 --apply
  $0 --apply --remote
  $0 --apply --remote --pr-force --pr-pattern '^(chore/|feat/)'
EOF
}

have() { command -v "$1" >/dev/null 2>&1; }

# ----------------------- Args ---------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) DO_APPLY=1; shift ;;
    --dry-run) DO_APPLY=0; shift ;;
    --remote) DO_REMOTE=1; shift ;;
    --base) BASE_REF="${2:-}"; shift 2 ;;
    --keep) KEEP_REGEX="${2:-}"; shift 2 ;;
    --inactive) INACTIVE_DAYS="${2:-0}"; shift 2 ;;
    --pr-force) PR_FORCE=1; shift ;;
    --pr-pattern) PR_PATTERN="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "Arg inconnu: $1 (voir --help)" ;;
  esac
done

# ----------------------- Sanity -------------------------
$GIT rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Pas dans un repo git."
log "Fetch + prune…"
$GIT fetch --all --prune >/dev/null 2>&1 || true
$GIT remote prune origin >/dev/null 2>&1 || true
$GIT rev-parse --verify "$BASE_REF" >/dev/null 2>&1 || die "Base introuvable: $BASE_REF"

# ----------------------- Local merged -------------------
log "Branches LOCALES mergées dans ${BASE_REF} (hors keep '${KEEP_REGEX}') :"
LOCAL_CANDS=$($GIT branch --format='%(refname:short)' --merged "$BASE_REF" | grep -Ev "${KEEP_REGEX}" || true)
if [[ -z "${LOCAL_CANDS}" ]]; then
  log "Aucune candidate locale."
else
  echo "${LOCAL_CANDS}" | sed 's/^/  - /'
  if (( DO_APPLY )); then
    CURR=$($GIT rev-parse --abbrev-ref HEAD)
    $GIT switch --detach "$BASE_REF" >/dev/null 2>&1 || true
    while read -r b; do
      [[ -z "$b" ]] && continue
      if $GIT merge-base --is-ancestor "$b" "$BASE_REF"; then
        $GIT branch -d "$b" || $GIT branch -D "$b"
      else
        warn "Skip $b (pas ancêtre de ${BASE_REF})."
      fi
    done <<< "${LOCAL_CANDS}"
    $GIT switch "$CURR" >/dev/null 2>&1 || true
    log "Suppression LOCALE effectuée."
  else
    warn "Dry-run : aucune suppression locale effectuée (ajoute --apply)."
  fi
fi

# ----------------------- Remote merged ------------------
if (( DO_REMOTE )); then
  log "Branches DISTANTES mergées dans ${BASE_REF} (hors keep) :"
  REMOTE_CANDS=$($GIT branch -r --format='%(refname:short)' --merged "$BASE_REF" \
    | sed 's#^origin/##' \
    | grep -Ev "${KEEP_REGEX}" \
    | grep -v '^HEAD$' || true)
  if [[ -z "${REMOTE_CANDS}" ]]; then
    log "Aucune candidate distante."
  else
    echo "${REMOTE_CANDS}" | sed 's/^/  - origin\//'
    if (( DO_APPLY )); then
      while read -r b; do
        [[ -z "$b" ]] && continue
        $GIT push origin --delete "$b"
      done <<< "${REMOTE_CANDS}"
      log "Suppression DISTANTE effectuée."
    else
      warn "Dry-run : aucune suppression distante effectuée (ajoute --apply)."
    fi
  fi
fi

# ----------------------- PR branches without open PR ----
if (( PR_FORCE )); then
  log "Branches PR sans PR ouverte (pattern '${PR_PATTERN}', hors keep) :"
  # On cible d'abord les DISTANTES (origin/*), car c’est là que l’UI PR s’appuie.
  PR_REMOTE=$($GIT for-each-ref --format='%(refname:short)' refs/remotes/origin \
    | sed 's#^origin/##' \
    | grep -Ev "${KEEP_REGEX}" \
    | grep -E "${PR_PATTERN}" || true)

  DEL_REMOTE=""
  if [[ -n "${PR_REMOTE}" ]]; then
    while read -r b; do
      [[ -z "$b" ]] && continue
      OPEN_PR=0
      if have gh; then
        # 0 = pas de PR ouverte, >0 = au moins une PR
        count=$(gh pr list --head "$b" --state open --json number -q 'length' 2>/dev/null || echo 0)
        [[ "${count}" -gt 0 ]] && OPEN_PR=1
      fi
      if [[ "${OPEN_PR}" -eq 0 ]]; then
        # sécurité si gh absent : ne supprime que si déjà inclus dans BASE_REF
        if $GIT merge-base --is-ancestor "origin/$b" "$BASE_REF"; then
          DEL_REMOTE+="$b"$'\n'
        else
          warn "Skip $b (pas de gh et pas inclus dans ${BASE_REF})"
        fi
      else
        warn "Skip $b (PR ouverte détectée)"
      fi
    done <<< "${PR_REMOTE}"
  fi

  if [[ -n "${DEL_REMOTE}" ]]; then
    echo "${DEL_REMOTE}" | sed 's/^/  - origin\//'
    if (( DO_APPLY )); then
      while read -r b; do
        [[ -z "$b" ]] && continue
        $GIT push origin --delete "$b"
      done <<< "${DEL_REMOTE}"
      log "Suppression DISTANTE des branches PR effectuée."
    else
      warn "Dry-run : ajoute --apply pour supprimer ces branches PR."
    fi
  else
    log "Aucune branche PR distante à supprimer."
  fi

  # Local : même logique, mais on vérifie inclusion et/ou PR ouverte
  PR_LOCAL=$($GIT for-each-ref --format='%(refname:short)' refs/heads \
    | grep -Ev "${KEEP_REGEX}" \
    | grep -E "${PR_PATTERN}" || true)

  DEL_LOCAL=""
  if [[ -n "${PR_LOCAL}" ]]; then
    while read -r b; do
      [[ -z "$b" ]] && continue
      OPEN_PR=0
      if have gh; then
        count=$(gh pr list --head "$b" --state open --json number -q 'length' 2>/dev/null || echo 0)
        [[ "${count}" -gt 0 ]] && OPEN_PR=1
      fi
      if [[ "${OPEN_PR}" -eq 0 ]]; then
        if $GIT merge-base --is-ancestor "$b" "$BASE_REF"; then
          DEL_LOCAL+="$b"$'\n'
        else
          warn "Skip local $b (pas inclus dans ${BASE_REF})"
        fi
      else
        warn "Skip local $b (PR ouverte détectée)"
      fi
    done <<< "${PR_LOCAL}"
  fi

  if [[ -n "${DEL_LOCAL}" ]]; then
    echo "${DEL_LOCAL}" | sed 's/^/  - /'
    if (( DO_APPLY )); then
      CURR=$($GIT rev-parse --abbrev-ref HEAD)
      $GIT switch --detach "$BASE_REF" >/dev/null 2>&1 || true
      while read -r b; do
        [[ -z "$b" ]] && continue
        $GIT branch -d "$b" || $GIT branch -D "$b"
      done <<< "${DEL_LOCAL}"
      $GIT switch "$CURR" >/dev/null 2>&1 || true
      log "Suppression LOCALE des branches PR effectuée."
    else
      warn "Dry-run : ajoute --apply pour supprimer ces branches PR."
    fi
  else
    log "Aucune branche PR locale à supprimer."
  fi
fi

# ----------------------- Inactivity report --------------
if (( INACTIVE_DAYS > 0 )); then
  if date -u -d @0 >/dev/null 2>&1; then
    CUTOFF=$(date -u -d "@$(( $(date +%s) - INACTIVE_DAYS*24*3600 ))" +%Y-%m-%d)
  else
    CUTOFF=$(python3 - <<PY
import time,datetime
print((datetime.datetime.utcnow()-datetime.timedelta(days=${INACTIVE_DAYS})).strftime('%Y-%m-%d'))
PY
)
  fi
  log "Branches LOCALES inactives > ${INACTIVE_DAYS}j (info) :"
  $GIT for-each-ref --format='%(committerdate:short) %(refname:short)' refs/heads \
    | awk -v cutoff="$CUTOFF" '$1 <= cutoff {print "  - "$2}' || true

  log "Branches DISTANTES inactives > ${INACTIVE_DAYS}j (info) :"
  $GIT for-each-ref --format='%(committerdate:short) %(refname:short)' refs/remotes/origin \
    | awk -v cutoff="$CUTOFF" '$1 <= cutoff {print "  - "$2}' || true
fi

log "Terminé."
