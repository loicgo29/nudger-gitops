#!/usr/bin/env bash
set -euo pipefail

# gitops-tag.sh — Tag GitOps daté + scope + type
# Exemple: v20250906-2010-whoami-feat-r2

show_help() {
  cat <<'EOF'
gitops-tag.sh — Crée un tag GitOps daté + scope + type.

Usage:
  scripts/gitops-tag.sh [options]

Options:
  --scope <name>   Forcer un scope (sinon auto-détection)
  --type <name>    Forcer un type (breaking|feat|fix|misc)
  --dry-run        Affiche le tag sans le créer/pousser
  --no-push        Crée le tag localement mais ne le pousse pas
  -h, --help       Affiche cette aide

Exemples:
  # Tag auto (scope et type auto)
  scripts/gitops-tag.sh

  # Forcer un scope et ne rien pousser
  scripts/gitops-tag.sh --scope ingress --no-push

  # Forcer un type et juste afficher
  scripts/gitops-tag.sh --type fix --dry-run
EOF
}
git remote set-url origin git@github.com:loicgo29/nudger-gitops.git
SCOPE_OVERRIDE=""
TYPE_OVERRIDE=""
DRY_RUN="false"
DO_PUSH="true"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope) SCOPE_OVERRIDE="${2:-}"; shift 2;;
    --type)  TYPE_OVERRIDE="${2:-}";  shift 2;;
    --dry-run) DRY_RUN="true"; shift;;
    --no-push) DO_PUSH="false"; shift;;
    -h|--help) show_help; exit 0;;
    *) echo "❌ Argument inconnu: $1" >&2; exit 2;;
  esac
done

# 0) Garde-fous basiques
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "❌ Pas un repo git."; exit 1; }

# 1) Dernier tag connu (sinon point de base = premier commit)
last_tag="$(git tag --sort=-creatordate | head -n1 || true)"
if [[ -z "${last_tag}" ]]; then
  base_ref="$(git rev-list --max-parents=0 HEAD | tail -n1)"
else
  base_ref="${last_tag}"
fi

# 2) Déterminer le scope automatiquement (top-level dir modifié)
#    - Si plusieurs dossiers: "multi"
#    - Si fichiers à la racine: "root"
changed_paths="$(git diff --name-only "${base_ref}"..HEAD || true)"
if [[ -n "${SCOPE_OVERRIDE}" ]]; then
  scope="${SCOPE_OVERRIDE}"
else
  if [[ -z "${changed_paths}" ]]; then
    # rien depuis le dernier tag => fallback au nom de branch
    scope="$(git rev-parse --abbrev-ref HEAD | tr '/.' '-')"
  else
    mapfile -t tops < <(echo "${changed_paths}" | awk -F/ '{print $1}' | sed 's|^\.$|root|' | sort -u)
    if   [[ "${#tops[@]}" -eq 0 ]]; then scope="root"
    elif [[ "${#tops[@]}" -eq 1 ]]; then scope="${tops[0]}"
    else scope="multi"
    fi
  fi
fi
scope="${scope//[^a-zA-Z0-9._-]/-}"    # hygiène
scope="${scope,,}"                     # lowercase

# 3) Déterminer le type (breaking/feat/fix/misc) à partir des commits
detect_type() {
  local range
  if [[ -z "${last_tag}" ]]; then
    range="$(git rev-list --oneline HEAD)"
  else
    range="$(git log --pretty=%B "${last_tag}"..HEAD || true)"
  fi
  if echo "${range}" | grep -qi 'BREAKING'; then
    echo "breaking"
  elif echo "${range}" | grep -Eqi '(^|\s)feat(\(|:|\s)'; then
    echo "feat"
  elif echo "${range}" | grep -Eqi '(^|\s)fix(\(|:|\s)'; then
    echo "fix"
  else
    echo "misc"
  fi
}

if [[ -n "${TYPE_OVERRIDE}" ]]; then
  type="${TYPE_OVERRIDE}"
else
  type="$(detect_type)"
fi
type="${type//[^a-zA-Z0-9._-]/-}"
type="${type,,}"

# 4) Préfixe daté (UTC) + anti-collision -rN pour la même minute/scope/type
stamp="$(date -u +%Y%m%d-%H%M)"
prefix="v${stamp}-${scope}-${type}"
# Trouver rN existants
existing_count="$(git tag --list "${prefix}*" | sed -n 's/^.*-r\([0-9]\+\)$/\1/p' | sort -n | tail -n1 || true)"
if [[ -z "${existing_count}" ]]; then
  suffix="r1"
else
  suffix="r$((existing_count + 1))"
fi
new_tag="${prefix}-${suffix}"

# 5) Message annoté utile
branch="$(git rev-parse --abbrev-ref HEAD)"
shortsha="$(git rev-parse --short HEAD)"
author="$(git log -1 --pretty=format:%an)"
subject="$(git log -1 --pretty=format:%s)"

annot_msg=$(
cat <<EOF
GitOps checkpoint
Tag:        ${new_tag}
Branch:     ${branch}
Commit:     ${shortsha} — ${subject}
Auteur:     ${author}
Base:       ${base_ref:-<none>}
Scope:      ${scope}
Type:       ${type}
Horodatage: $(date -u +"%F %T UTC")

Changements (depuis ${last_tag:-<repo root>}):
$(git log --oneline "${base_ref}"..HEAD || echo "  (aucun)")
EOF
)

# 6) Affichage / dry-run
echo "👉 Tag proposé: ${new_tag}"
echo "   scope=${scope} type=${type} base=${base_ref:-root} branch=${branch} sha=${shortsha}"
if [[ "${DRY_RUN}" == "true" ]]; then
  echo "— DRY RUN — aucun tag créé/poussé."
  exit 0
fi

# 7) Création + push
git tag -a "${new_tag}" -m "${annot_msg}"
echo "✅ Tag créé: ${new_tag}"
if [[ "${DO_PUSH}" == "true" ]]; then
  git push origin "${new_tag}"
  echo "🚀 Tag poussé: ${new_tag}"
else
  echo "ℹ️  Tag local uniquement (non poussé)."
fi
