#!/usr/bin/env bash
# -------------------------------------------------------------
# auto-pr-from-flux.sh
# - Détecte la branche flux-imageupdates* (ou --head fourni)
# - Crée une branche unique et pousse
# - Ouvre une PR vers --base (main par défaut)
# - Best effort sur labels ; jamais bloquant
# -------------------------------------------------------------
set -euo pipefail

# ====== Params & flags ======
BASE_BRANCH="${BASE_BRANCH:-main}"
HEAD_PREFIX="${HEAD_PREFIX:-flux-imageupdates}"
HEAD_BRANCH="${HEAD_BRANCH:-}"
GIT_REMOTE="${GIT_REMOTE:-origin}"
DRY_RUN="${DRY_RUN:-0}"
VERBOSE="${VERBOSE:-1}"
PR_TITLE_TEMPLATE='chore(images): Flux updates (%s)'

usage() {
  cat >&2 <<EOF
Usage: $0 [--base main] [--head flux-imageupdates-...]
  ENV support:
    BASE_BRANCH, HEAD_PREFIX, HEAD_BRANCH, GIT_REMOTE, DRY_RUN, VERBOSE
EOF
}

log()  { echo -e "$*"; }
vlog() { [[ "$VERBOSE" == "1" ]] && echo -e "$*" || true; }
die()  { echo -e "ERROR: $*" >&2; exit 1; }

# parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) BASE_BRANCH="$2"; shift 2;;
    --head) HEAD_BRANCH="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) die "Unknown arg: $1";;
  esac
done

vlog "[INFO] BASE_BRANCH=${BASE_BRANCH}"
vlog "[INFO] HEAD_PREFIX=${HEAD_PREFIX}"
vlog "[INFO] HEAD_BRANCH(in)=${HEAD_BRANCH}"
vlog "[INFO] GIT_REMOTE=${GIT_REMOTE}"
vlog "[INFO] DRY_RUN=${DRY_RUN} VERBOSE=${VERBOSE}"

# ====== Helpers ======
strip_remote() {
  local r="${1:-}"
  r="${r#refs/remotes/}"
  r="${r#${GIT_REMOTE}/}"
  echo "$r"
}

repo_full_from_remote() {
  local url
  url="$(git remote get-url "${GIT_REMOTE}" 2>/dev/null || true)"
  if [[ "${url}" =~ github.com[:/]+([^/]+/[^/.]+)(\.git)?$ ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo ""
  fi
}

ensure_ref_exists() {
  local ref="$1"
  git rev-parse --verify "$ref" >/dev/null 2>&1
}

# ====== Fetch ======
git fetch "${GIT_REMOTE}" "+refs/heads/*:refs/remotes/${GIT_REMOTE}/*"

# ====== Determine HEAD branch ======
if [[ -z "${HEAD_BRANCH}" ]]; then
  if [[ "${GITHUB_EVENT_NAME:-}" == "workflow_dispatch" && -n "${GITHUB_EVENT_INPUTS_HEAD_BRANCH:-}" ]]; then
    HEAD_BRANCH="${GITHUB_EVENT_INPUTS_HEAD_BRANCH}"
  else
    DETECTED="$(git for-each-ref --sort=-committerdate --format='%(refname:short)' \
      "refs/remotes/${GIT_REMOTE}/${HEAD_PREFIX}*" | head -n1 || true)"
    if [[ -n "${DETECTED}" ]]; then
      HEAD_BRANCH="$(strip_remote "${DETECTED}")"
    elif ensure_ref_exists "refs/remotes/${GIT_REMOTE}/${HEAD_PREFIX}"; then
      HEAD_BRANCH="${HEAD_PREFIX}"
    else
      log "[INFO] Aucune branche '${HEAD_PREFIX}*' trouvée sur ${GIT_REMOTE}. Fin."
      exit 0
    fi
  fi
fi

HEAD_BRANCH="$(strip_remote "${HEAD_BRANCH}")"
BASE_REF="${GIT_REMOTE}/${BASE_BRANCH}"
HEAD_REF="${GIT_REMOTE}/${HEAD_BRANCH}"

vlog "[INFO] HEAD_BRANCH(out)=${HEAD_BRANCH}"
vlog "BASE=${BASE_REF}  HEAD=${HEAD_REF}"

ensure_ref_exists "${HEAD_REF}" || { log "[INFO] La branche ${HEAD_REF} n'existe pas. Fin."; exit 0; }

BASE_SHA="$(git rev-parse "${BASE_REF}")"
HEAD_SHA="$(git rev-parse "${HEAD_REF}")"
vlog "BASE SHA: ${BASE_SHA}"
vlog "HEAD SHA: ${HEAD_SHA}"

AHEAD="$(git rev-list --count "${BASE_REF}..${HEAD_REF}")"
log "[INFO] Commits ahead = ${AHEAD}"
if [[ "${AHEAD}" -le 0 ]]; then
  log "[INFO] Pas de commit à intégrer. Fin."
  exit 0
fi

# ====== Create unique branch ======
SHORT_SHA="${HEAD_SHA:0:7}"
STAMP="$(date +%Y%m%d-%H%M%S)"
SAFE_HEAD="$(basename "${HEAD_BRANCH}")"
NEW_BRANCH="${SAFE_HEAD}-${SHORT_SHA}-${STAMP}"
PR_TITLE="$(printf "${PR_TITLE_TEMPLATE}" "${NEW_BRANCH}")"

if [[ "${DRY_RUN}" != "1" ]]; then
  git switch --detach "${HEAD_REF}"
  git checkout -b "${NEW_BRANCH}"
  git push "${GIT_REMOTE}" "${NEW_BRANCH}:${NEW_BRANCH}"
  log "[INFO] Branche ${NEW_BRANCH} créée et poussée."
else
  vlog "[DRY_RUN] git switch --detach ${HEAD_REF}"
  vlog "[DRY_RUN] git checkout -b ${NEW_BRANCH}"
  vlog "[DRY_RUN] git push ${GIT_REMOTE} ${NEW_BRANCH}:${NEW_BRANCH}"
fi
# Si on est dans Actions, on s'attend à avoir GH_TOKEN
if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  if [[ -z "${GH_TOKEN:-}" ]]; then
    echo "[WARN] GH_TOKEN absent dans Actions, gh risque d'échouer."
  fi
else
  # En local: ne pas laisser des variables vides casser gh
  if [[ -z "${GH_TOKEN:-}" ]]; then unset GH_TOKEN; fi
  if [[ -z "${GITHUB_TOKEN:-}" ]]; then unset GITHUB_TOKEN; fi
fi
# Si gh est déjà authentifié, on ignore d’éventuels GH_TOKEN/GITHUB_TOKEN vides
if gh auth status >/dev/null 2>&1; then
  [[ -n "${GH_TOKEN:-}" && "${GH_TOKEN}" = '""' ]] && unset GH_TOKEN
  [[ -n "${GITHUB_TOKEN:-}" && "${GITHUB_TOKEN}" = '""' ]] && unset GITHUB_TOKEN
fi

# Détermine le repo si gh a du mal à le deviner
if ! REPO_FULL="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)"; then
  ORIGIN_URL="$(git remote get-url "${GIT_REMOTE}" 2>/dev/null || true)"
  REPO_FULL="$(echo "$ORIGIN_URL" | sed -E 's#.*github.com[:/]+([^/]+/[^/.]+)(\.git)?$#\1#')"
fi
# ====== Prepare repo slug (owner/name) ======
REPO_FULL="$(repo_full_from_remote)"
if command -v gh >/dev/null 2>&1 && [[ -z "${REPO_FULL}" ]]; then
  # fallback via gh si token dispo
  REPO_FULL="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")"
fi

# ====== Labels (best effort) ======
LABEL_FLAGS=()
if command -v gh >/dev/null 2>&1 && [[ -n "${REPO_FULL}" ]]; then
  # crée/ensure labels (indemPotent via API)
  gh api -X POST "repos/${REPO_FULL}/labels" \
    -f name="flux" -f color="FFD700" -f description="Flux automation" >/dev/null 2>&1 || true
  gh api -X POST "repos/${REPO_FULL}/labels" \
    -f name="automated-pr" -f color="1D76DB" -f description="Created by automation" >/dev/null 2>&1 || true
  LABEL_FLAGS+=( --label "flux" --label "automated-pr" )
else
  vlog "[WARN] gh non dispo ou repo inconnu, pas de labels."
fi

# ====== Create PR ======
if [[ "${DRY_RUN}" == "1" ]]; then
  vlog "[DRY_RUN] PR: ${NEW_BRANCH} -> ${BASE_BRANCH}"
  exit 0
fi

if command -v gh >/dev/null 2>&1 && [[ -n "${REPO_FULL}" ]]; then
  if gh pr create \
      --repo "${REPO_FULL}" \
      --head "${NEW_BRANCH}" \
      --base "${BASE_BRANCH}" \
      --title "${PR_TITLE}" \
      --body "PR auto générée depuis \`${NEW_BRANCH}\` (bump d’images via Flux)." \
      "${LABEL_FLAGS[@]}"; then
    gh pr list --repo "${REPO_FULL}" --head "${NEW_BRANCH}" --base "${BASE_BRANCH}" --state open \
      --json number,url -q '.[0] | "PR #"+(.number|tostring)+" → "+.url"' || true
  else
    echo "[WARN] gh pr create a échoué. Ouvre la PR manuellement :"
    echo "       https://github.com/${REPO_FULL}/compare/${BASE_BRANCH}...${NEW_BRANCH}?expand=1"
  fi
else
  if [[ -n "${REPO_FULL}" ]]; then
    echo "[WARN] gh absent. Ouvre la PR :"
    echo "       https://github.com/${REPO_FULL}/compare/${BASE_BRANCH}...${NEW_BRANCH}?expand=1"
  else
    echo "[WARN] Impossible de déterminer le repo GitHub. Ouvre la PR depuis l’UI."
  fi
fi
