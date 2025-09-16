#!/usr/bin/env bash
set -euo pipefail

DEBUG=false
if [[ "${1:-}" == "-d" ]]; then
  DEBUG=true
fi

echo "🔍 Recherche des YAML non utilisés dans les kustomizations..."

# Charger les patterns d'exclusion si .unusedignore existe
IGNORES=()
unusedignore=$HOME/nudger-gitops/scripts/autom/.unusedignore
if [[ -f "$unusedignore" ]]; then
  mapfile -t IGNORES < $unusedignore
fi

is_ignored() {
  local file="$1"
  for pat in "${IGNORES[@]}"; do
    # Match exact ou dans un dossier
    if [[ "$file" == "$pat" ]] || [[ "$file" == $pat/* ]]; then
      return 0
    fi
  done
  return 1
}

# 1. Lister tous les fichiers YAML (hors .git, scripts, tests, README…)
all_files=$(find . -type f \( -name "*.yaml" -o -name "*.yml" \) \
  ! -path "./.git/*" \
  ! -path "./scripts/*" \
  ! -path "./tests/*" \
  ! -name "kustomization.yaml" \
  ! -name "kustomization.yml")

# 2. Extraire les références depuis les kustomizations + HelmRelease/Kustomization
declare -A refs
while read -r kf; do
  [[ -z "$kf" ]] && continue
  while read -r ref; do
    [[ -z "$ref" ]] && continue
    ref=$(realpath --relative-to=. "$(dirname "$kf")/$ref" 2>/dev/null || echo "$ref")
    refs["$ref"]="$kf"
  done < <(
    yq eval '.resources[]?, .patches[]?.path?, .patchesStrategicMerge[]?, .spec.chart.spec.sourceRef.name?, .spec.sourceRef.name?' "$kf" 2>/dev/null \
      | grep -E '\.ya?ml$' || true
  )
done < <(find . -type f -name "kustomization.y*ml" -o -name "helmrelease.y*ml")

echo "────────────────────────────"
for file in $all_files; do
  rel=$(realpath --relative-to=. "$file" 2>/dev/null || echo "$file")

  if is_ignored "$rel"; then
    $DEBUG && echo "🚫 Ignoré (via .unusedignore) : $rel"
    continue
  fi

  if [[ -n "${refs[$rel]:-}" ]]; then
    echo "✅ Utilisé : $rel (via ${refs[$rel]})"
  else
    echo "❌ Non utilisé : $rel"
  fi
done

