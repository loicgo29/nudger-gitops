#!/usr/bin/env bash
set -euo pipefail

DEBUG=false
if [[ "${1:-}" == "-d" ]]; then
  DEBUG=true
fi

echo "🔍 Recherche des YAML non utilisés dans les kustomizations..."

# 1. Lister tous les fichiers YAML (hors .git, scripts, tests, README…)
all_files=$(find . -type f \( -name "*.yaml" -o -name "*.yml" \) \
  ! -path "./.git/*" \
  ! -path "./scripts/*" \
  ! -path "./tests/*" \
  ! -name "kustomization.yaml" \
  ! -name "kustomization.yml")

# 2. Extraire les références depuis les kustomizations
declare -A refs
while read -r kf; do
  [[ -z "$kf" ]] && continue
  while read -r ref; do
    [[ -z "$ref" ]] && continue
    # Normalise en chemin relatif
    ref=$(realpath --relative-to=. "$(dirname "$kf")/$ref" 2>/dev/null || echo "$ref")
    refs["$ref"]="$kf"
  done < <(
    yq eval '.resources[]?, .patches[]?.path?, .patchesStrategicMerge[]?' "$kf" 2>/dev/null \
      | grep -E '\.ya?ml$' || true
  )
done < <(find . -type f -name "kustomization.y*ml")

echo "────────────────────────────"
for file in $all_files; do
  rel=$(realpath --relative-to=. "$file" 2>/dev/null || echo "$file")
  if [[ -n "${refs[$rel]:-}" ]]; then
    $DEBUG && echo "✅ Utilisé : $rel (via ${refs[$rel]})"
  else
    echo "❌ Non utilisé : $rel"
  fi
done
