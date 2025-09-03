#!/usr/bin/env bash
# bump-multi.sh — Bump d'images sur plusieurs fichiers Helm values.yaml ou kustomization.yaml
# - Idempotent : ne modifie qu'en cas de vrai changement
# - Kustomize : crée .images[] si absent, update/insert par .name
# - Helm      : modifie .image.repository / .image.tag
# - Valide kustomize (kustomize build + kubeconform) si des kustomizations ont changé
# - Expose des outputs GitHub (changed=true/false, files=liste)

set -euo pipefail

# ---------- Args ----------
KIND=""
PATHS=""
REPO=""
TAG=""
NAME=""

usage() {
  cat <<EOF
Usage:
  $0 --kind (helm|kustomize) --paths "file1.yaml,file2.yaml" --image-repo REPO --image-tag TAG [--name NAME]
Exemples:
  $0 --kind helm --paths "apps/a/values.yaml,apps/b/values.yaml" --image-repo org/app --image-tag 1.2.3
  $0 --kind kustomize --paths "apps/a/kustomization.yaml" --image-repo traefik/whoami --image-tag v1.10.1 --name whoami
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --kind)       KIND="${2:-}"; shift 2;;
    --paths)      PATHS="${2:-}"; shift 2;;
    --image-repo) REPO="${2:-}"; shift 2;;
    --image-tag)  TAG="${2:-}"; shift 2;;
    --name)       NAME="${2:-}"; shift 2;;
    -h|--help)    usage; exit 0;;
    *) echo "Arg inconnu: $1"; usage; exit 2;;
  esac
done

[[ -n "$KIND" && -n "$PATHS" && -n "$REPO" && -n "$TAG" ]] || { echo "Inputs manquants."; usage; exit 2; }
if [[ "$KIND" == "kustomize" && -z "${NAME:-}" ]]; then
  echo "Pour kind=kustomize, --name est requis (images[].name)."; exit 2
fi

# Toujours bosser depuis la racine du repo (chemins stables)
if git rev-parse --show-toplevel >/dev/null 2>&1; then
  cd "$(git rev-parse --show-toplevel)"
fi

need() { command -v "$1" >/dev/null 2>&1 || { echo "Manquant: $1"; exit 1; }; }
need yq
if [[ "$KIND" == "kustomize" ]]; then need kustomize; need kubeconform; fi

# ---------- Utils ----------
trim() { sed 's/^[[:space:]]*//; s/[[:space:]]*$//' ; }
uniqlines() { awk 'NF' | sort -u; }

# Prépare la liste de fichiers
mapfile -t FILES < <(printf "%s" "$PATHS" | tr ',' '\n' | trim | uniqlines)

CHANGED_ANY=0
CHANGED_LIST=()

patch_helm() {
  local file="$1"
  local cur_repo cur_tag
  cur_repo="$(yq -r '.image.repository // ""' "$file" 2>/dev/null || true)"
  cur_tag="$( yq -r '.image.tag        // ""' "$file" 2>/dev/null || true)"
  if [[ "$cur_repo" == "$REPO" && "$cur_tag" == "$TAG" && -n "$cur_tag" ]]; then
    echo "noop: $file (déjà ${REPO}:${TAG})"
    return 0
  fi
  yq -i '
    .image.repository = env(REPO) |
    .image.tag        = env(TAG)
  ' "$file"
  echo "patched: $file"
  return 10
}

patch_kustomize() {
  local file="$1"
  # Assure .images[]
  if ! yq -e 'has("images")' "$file" >/dev/null 2>&1; then
    yq -i '.images = []' "$file"
  fi
  local cur_repo cur_tag
  cur_repo="$(yq -r ".images[] | select(.name == \"$NAME\") | .newName" "$file" 2>/dev/null || true)"
  cur_tag="$( yq -r ".images[] | select(.name == \"$NAME\") | .newTag"  "$file" 2>/dev/null || true)"
  if [[ "$cur_repo" == "$REPO" && "$cur_tag" == "$TAG" && -n "$cur_tag" ]]; then
    echo "noop: $file (déjà ${REPO}:${TAG})"
    return 0
  fi
  if yq -e ".images[] | select(.name == \"$NAME\")" "$file" >/dev/null 2>&1; then
    yq -i '
      (.images[] | select(.name == env(NAME)).newName) = env(REPO) |
      (.images[] | select(.name == env(NAME)).newTag)  = env(TAG)
    ' "$file"
  else
    yq -i '.images += [{"name": env(NAME), "newName": env(REPO), "newTag": env(TAG)}]' "$file"
  fi
  echo "patched: $file"
  return 10
}

# Collecte les dossiers kustomize modifiés pour validation
declare -A KUSTOM_DIRS=()

for f in "${FILES[@]}"; do
  [[ -z "$f" ]] && continue
  if [[ ! -f "$f" ]]; then
    echo "skip: introuvable -> $f"
    continue
  fi
  if [[ "$KIND" == "helm" ]]; then
    if patch_helm "$f"; then :; else CHANGED_ANY=1; CHANGED_LIST+=("$f"); fi
  else
    if patch_kustomize "$f"; then :; else CHANGED_ANY=1; CHANGED_LIST+=("$f"); KUSTOM_DIRS["$(dirname "$f")"]=1; fi
  fi
done

# Validation Kustomize si nécessaire
if [[ "$KIND" == "kustomize" && "$CHANGED_ANY" -eq 1 ]]; then
  for d in "${!KUSTOM_DIRS[@]}"; do
    echo "validate: kustomize build $d"
    kustomize build "$d" | tee "/tmp/kustom-${RANDOM}.yaml" >/dev/null
    kubeconform -strict -ignore-missing-schemas -summary < "/tmp/kustom-${RANDOM}.yaml"
  done
fi

# Expose outputs pour GitHub Actions
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  if [[ "$CHANGED_ANY" -eq 1 ]]; then
    printf "changed=true\n" >> "$GITHUB_OUTPUT"
    # Liste CSV pour le body de PR
    (IFS=','; printf "files=%s\n" "$(printf "%s" "${CHANGED_LIST[*]}" | tr ' ' ',' )") >> "$GITHUB_OUTPUT"
  else
    printf "changed=false\n" >> "$GITHUB_OUTPUT"
    printf "files=\n" >> "$GITHUB_OUTPUT"
  fi
fi

# Log final
if [[ "$CHANGED_ANY" -eq 1 ]]; then
  echo "OK: changements appliqués."
else
  echo "No-op: rien à modifier."
fi
