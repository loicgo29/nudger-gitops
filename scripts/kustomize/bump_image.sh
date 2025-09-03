#!/usr/bin/env bash
# bump-image.sh — Met à jour .images[].(newName,newTag) dans un kustomization.yaml
# Idempotent : crée une PR seulement si un vrai changement est appliqué.
# Valide le rendu via kustomize + kubeconform.

set -euo pipefail

# -------- Args / Env --------
FILE="${FILE:-}"
NAME="${NAME:-}"
REPO="${REPO:-}"
TAG="${TAG:-}"

usage() {
  cat <<EOF
Usage: $0 --file PATH --name NAME --image-repo REPO --image-tag TAG
Ex:
  $0 --file apps/whoami/kustomization.yaml --name whoami --image-repo traefik/whoami --image-tag v1.10.1
EOF
}

# Parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --file) FILE="${2:-}"; shift 2;;
    --name) NAME="${2:-}"; shift 2;;
    --image-repo) REPO="${2:-}"; shift 2;;
    --image-tag) TAG="${2:-}"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Arg inconnu: $1"; usage; exit 2;;
  esac
done

[[ -n "$FILE" && -n "$NAME" && -n "$REPO" && -n "$TAG" ]] || { echo "Args manquants."; usage; exit 2; }
[[ -f "$FILE" ]] || { echo "Fichier introuvable: $FILE"; exit 1; }

# -------- Déps requises --------
need() { command -v "$1" >/dev/null 2>&1 || { echo "Manquant: $1"; exit 1; }; }
need yq
need kustomize
need kubeconform
need git

# -------- Patch idempotent --------
# Crée images[] s'il n'existe pas ou vaut null
if ! yq -e 'has("images")' "$FILE" >/dev/null 2>&1; then
  yq -i '.images = []' "$FILE"
fi

CUR_REPO="$(yq -r ".images[] | select(.name == \"$NAME\") | .newName" "$FILE" 2>/dev/null || true)"
CUR_TAG="$( yq -r ".images[] | select(.name == \"$NAME\") | .newTag"  "$FILE" 2>/dev/null || true)"

# No-op ?
if [[ "$CUR_REPO" == "$REPO" && "$CUR_TAG" == "$TAG" && -n "$CUR_TAG" ]]; then
  echo "Déjà sur ${REPO}:${TAG} (name=${NAME})."
  # Expose outputs pour le workflow (si variable présente)
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    {
      echo "noop=true"
      echo "file=$FILE"
    } >> "$GITHUB_OUTPUT"
  fi
  exit 0
fi

# Update/insert entrée .images[name==NAME]
if yq -e ".images[] | select(.name == \"$NAME\")" "$FILE" >/dev/null 2>&1; then
  yq -i '
    (.images[] | select(.name == "'"$NAME"'").newName) = "'"$REPO"'" |
    (.images[] | select(.name == "'"$NAME"'").newTag)  = "'"$TAG"'"
  ' "$FILE"
else
  yq -i '.images += [{"name":"'"$NAME"'", "newName":"'"$REPO"'", "newTag":"'"$TAG"'"}]' "$FILE"
fi

# -------- Validation rendu --------
MANIFEST="/tmp/kustomize-${RANDOM}.yaml"
kustomize build "$(dirname "$FILE")" | tee "$MANIFEST" >/dev/null
kubeconform -strict -ignore-missing-schemas -summary < "$MANIFEST"

# -------- Expose outputs (pour le workflow) --------
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "noop=false"
    echo "file=$FILE"
  } >> "$GITHUB_OUTPUT"
fi

echo "Patch OK + validation OK → prêt pour PR."
