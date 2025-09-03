#!/usr/bin/env bash
# -------------------------------------------------------------
# auto-pr-from-flux.sh
# But :
#  - Détecter la branche poussée par Flux (flux-imageupdates*),
#  - Créer une branche unique à partir de celle-ci,
#  - Ouvrir une PR vers main (avec labels si possible),
#  - Ne jamais planter pour des détails (labels/gh).
# -------------------------------------------------------------
set -euo pipefail

# ====== Paramètres ======
BASE_BRANCH="${BASE_BRANCH:-main}"                 # base de la PR
HEAD_BRANCH="${HEAD_BRANCH:-}"                     # branche source explicite (sinon auto-détection)
HEAD_PREFIX="${HEAD_PREFIX:-flux-imageupdates}"    # préfixe des branches Flux
GIT_REMOTE="${GIT_REMOTE:-origin}"                 # remote git
DRY_RUN="${DRY_RUN:-0}"                            # 1 = pas de push ni PR
VERBOSE="${VERBOSE:-1}"                            # 1 = logs verbeux
DEBUG="${DEBUG:-0}"                                # 1 = logs debug (stderr)
PR_TITLE_TEMPLATE='chore(images): Flux updates (%s)' # sprintf avec NEW_BRANCH

# ====== Helpers ======
mask() { sed -E 's/(ghp_[A-Za-z0-9]+|github_pat_[A-Za-z0-9_]+|gho_[A-Za-z0-9_]+|glpat-[A-Za-z0-9_]+)/***REDACTED***/g'; }
log()   { echo -e "$@"; }
vlog()  { [[ "$VERBOSE" == "1" ]] && echo -e "$@" || true; }
dbg()   { [[ "$DEBUG" == "1" ]] && echo "[DBG] $*" >&2 || true; }

# Normalise un nom de ref → "branche" sans remote
strip_remote() {
  local r="${1:-}"
  r="${r#refs/remotes/}"
  r="${r#${GIT_REMOTE}/}"
  echo "$r"
}

# Renvoie "owner/repo" si le remote est GitHub, sinon ""
repo_full_from_remote() {
  local url slug
  url="$(git remote get-url "${GIT_REMOTE}" 2>/dev/null || true)"
  dbg "remote url: $(echo "$url" | mask)"
  if [[ "${url}" =~ github.com[:/]+([^/]+/[^/.]+)(\.git)?$ ]]; then
    slug="${BASH_REMATCH[1]}"
    echo "${slug}"
  else
    echo ""
  fi
}

# Contexte utile en debug
dump_git_context() {
  echo "---- GIT CONTEXT ----" >&2
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Not a git repo" >&2; return; }
  echo "Remote URLs:" >&2
  git remote -v | mask >&2
  echo "Current HEAD:" >&2
  git log --oneline -1 | mask >&2 || true
  echo "Branches (last 5):" >&2
  git for-each-ref --sort=-committerdate --format='%(refname:short) %(objectname:short)  %(subject)' refs/heads | head -n5 | mask >&2 || true
  echo "Remote branches (last 8):" >&2
  git for-each-ref --sort=-committerdate --format='%(refname:short) %(objectname:short)  %(subject)' "refs/remotes/${GIT_REMOTE}" | head -n8 | mask >&2 || true
  echo "----------------------" >&2
}

dump_env_context() {
  echo "---- ENV CONTEXT ----" | mask >&2
  echo "GITHUB_ACTIONS=${GITHUB_ACTIONS:-}" | mask >&2
  [[ -n "${GH_TOKEN:-}" ]] && echo "GH_TOKEN set? yes" >&2 || echo "GH_TOKEN set? no" >&2
  [[ -n "${GITHUB_TOKEN:-}" ]] && echo "GITHUB_TOKEN set? yes" >&2 || echo "GITHUB_TOKEN set? no" >&2
  echo "---------------------" >&2
}

# ====== Logs init ======
vlog "[INFO] BASE_BRANCH=${BASE_BRANCH}"
vlog "[INFO] HEAD_PREFIX=${HEAD_PREFIX}"
vlog "[INFO] HEAD_BRANCH(in)=${HEAD_BRANCH}"
vlog "[INFO] GIT_REMOTE=${GIT_REMOTE}"
vlog "[INFO] DRY_RUN=${DRY_RUN} VERBOSE=${VERBOSE} DEBUG=${DEBUG}"
[[ "$DEBUG" == "1" ]] && dump_git_context
[[ "$DEBUG" == "1" ]] && dump_env_context

# ====== Fetch des refs ======
git fetch "${GIT_REMOTE}" "+refs/heads/*:refs/remotes/${GIT_REMOTE}/*"

# ====== Détermination de la branche HEAD ======
if [[ -z "${HEAD_BRANCH}" ]]; then
  if [[ "${GITHUB_EVENT_NAME:-}" == "workflow_dispatch" && -n "${GITHUB_EVENT_INPUTS_HEAD_BRANCH:-}" ]]; then
    HEAD_BRANCH="${GITHUB_EVENT_INPUTS_HEAD_BRANCH}"
  else
    # branche distante la plus récente qui matche le préfixe
    DETECTED="$(git for-each-ref --sort=-committerdate --format='%(refname:short)' \
      "refs/remotes/${GIT_REMOTE}/${HEAD_PREFIX}*" | head -n1 || true)"
    dbg "DETECTED remote: ${DETECTED}"
    if [[ -n "${DETECTED}" ]]; then
      HEAD_BRANCH="$(strip_remote "${DETECTED}")"
    elif git rev-parse --verify "refs/remotes/${GIT_REMOTE}/${HEAD_PREFIX}" >/dev/null 2>&1; then
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

# Vérifie l’existence de HEAD_REF
if ! git rev-parse --verify "${HEAD_REF}" >/dev/null 2>&1; then
  log "[INFO] La branche ${HEAD_REF} n'existe pas. Fin."
  exit 0
fi

BASE_SHA="$(git rev-parse "${BASE_REF}")"
HEAD_SHA="$(git rev-parse "${HEAD_REF}")"
vlog "BASE SHA: ${BASE_SHA}"
vlog "HEAD SHA: ${HEAD_SHA}"

# Combien de commits d'avance ?
AHEAD="$(git rev-list --count "${BASE_REF}..${HEAD_REF}")"
log "[INFO] Commits ahead = ${AHEAD}"
if [[ "${AHEAD}" -le 0 ]]; then
  log "[INFO] Pas de commit à intégrer. Fin."
  exit 0
fi

# ====== Création de la branche PR ======
SRC_SHA="${HEAD_SHA}"
SHORT_SHA="${SRC_SHA:0:7}"
STAMP="$(date +%Y%m%d-%H%M%S)"
SAFE_HEAD="$(basename "${HEAD_BRANCH}")"
NEW_BRANCH="${SAFE_HEAD}-${SHORT_SHA}-${STAMP}"
PR_TITLE="$(printf "${PR_TITLE_TEMPLATE}" "${NEW_BRANCH}")"
dbg "NEW_BRANCH=${NEW_BRANCH}  PR_TITLE=${PR_TITLE}"

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

# ====== Labels best-effort (jamais bloquants) ======
LABEL_FLAGS=()
if command -v gh >/dev/null 2>&1; then
  REPO_FULL="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || repo_full_from_remote)"
  dbg "REPO_FULL=${REPO_FULL}"
  if [[ -n "${REPO_FULL}" ]]; then
    create_label() {
      local name="$1" color="$2" desc="$3"
      # Essayez l’API (plus stable cross-versions)
      gh api -X POST "repos/${REPO_FULL}/labels" \
        -f name="$name" -f color="$color" -f description="$desc" >/dev/null 2>&1 \
      || gh api -X PATCH "repos/${REPO_FULL}/labels/${name}" \
        -f new_name="$name" -f color="$color" -f description="$desc" >/dev/null 2>&1 || true
    }
    create_label "flux" "FFD700" "Flux automation"
    create_label "automated-pr" "1D76DB" "Created by automation"
    LABEL_FLAGS+=( --label "flux" --label "automated-pr" )
  else
    vlog "[WARN] gh OK mais repo introuvable, pas de labels."
  fi
else
  vlog "[WARN] gh non disponible, pas de labels."
fi

# ====== Création de la PR ======
if [[ "${DRY_RUN}" == "1" ]]; then
  vlog "[DRY_RUN] Création PR: ${NEW_BRANCH} -> ${BASE_BRANCH}"
  exit 0
fi

if command -v gh >/dev/null 2>&1; then
  # Si on a un slug repo valide, on le force via --repo (évite toute auto-déduction hasardeuse)
  REPO_FULL="${REPO_FULL:-$(repo_full_from_remote)}"
  if gh pr create \
      ${REPO_FULL:+--repo "${REPO_FULL}"} \
      --head "${NEW_BRANCH}" \
      --base "${BASE_BRANCH}" \
      --title "${PR_TITLE}" \
      --body "PR auto générée depuis \`${NEW_BRANCH}\` (bump d’images via Flux)." \
      "${LABEL_FLAGS[@]}"; then
    gh pr list \
      ${REPO_FULL:+--repo "${REPO_FULL}"} \
      --head "${NEW_BRANCH}" --base "${BASE_BRANCH}" --state open \
      --json number,url -q '.[0] | "PR #"+(.number|tostring)+" → "+.url"' || true
  else
    # Fallback : proposer l’URL de comparaison manuelle
    if [[ -z "${REPO_FULL}" ]]; then
      REPO_FULL="$(repo_full_from_remote)"
    fi
    if [[ -n "${REPO_FULL}" ]]; then
      echo "[WARN] gh pr create a échoué. Ouvre la PR manuellement :" >&2
      echo "       https://github.com/${REPO_FULL}/compare/${BASE_BRANCH}...${NEW_BRANCH}?expand=1" >&2
    else
      echo "[WARN] gh pr create a échoué et repo inconnu. Ouvre la PR dans l'UI GitHub." >&2
    fi
  fi
else
  # Sans gh : propose l’URL manuelle
  REPO_FULL="$(repo_full_from_remote)"
  if [[ -n "${REPO_FULL}" ]]; then
    echo "[WARN] gh non dispo. Ouvre la PR manuellement :" >&2
    echo "       https://github.com/${REPO_FULL}/compare/${BASE_BRANCH}...${NEW_BRANCH}?expand=1" >&2
  else
    echo "[WARN] gh non dispo et remote non GitHub. Ouvre la PR manuellement." >&2
  fi
fi
