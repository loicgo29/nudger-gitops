#!/usr/bin/env bash
set -euo pipefail

DEBUG=false
if [[ "${1:-}" == "-d" ]]; then
  DEBUG=true
fi

echo "🔍 Recherche des YAML non utilisés dans les kustomizations..."

# 1. Lister tous les fichiers YAML (hors .git, scripts, tests…)
all_files=$(find . -type f \( -name "*.yaml" -o -name "*.yml" \) \
  ! -path "./.git/*" \
  ! -path "./scripts/*" \
  ! -name "kustomization.yaml" \
  ! -name "kustomization.yml")

# 2. Charger les patterns d’ignore si présent
ignore_patterns=()
fileunusedignore=$HOME/nudger-gitops/scripts/autom/.unusedignore
if [[ -f "$fileunusedignore" ]]; then
  mapfile -t ignore_patterns < $fileunusedignore
fi

# 3. Extraire les références
declare -A refs

# Parcours des kustomization.yaml
while read -r kf; do
  [[ -z "$kf" ]] && continue
  while read -r ref; do
    [[ -z "$ref" ]] && continue
    ref=$(realpath --relative-to=. "$(dirname "$kf")/$ref" 2>/dev/null || echo "$ref")
    refs["$ref"]="$kf"
    $DEBUG && echo "➕ Resource/Patch ref -> $ref (via $kf)"
  done < <(
    yq eval '.resources[]?, .patches[]?.path?, .patchesStrategicMerge[]?' "$kf" 2>/dev/null \
      | grep -E '\.ya?ml$' || true
  )
done < <(find . -type f -name "kustomization.y*ml")

# Parcours des HelmRelease et Kustomization pour spec.sourceRef
while read -r f; do
  [[ -z "$f" ]] && continue
  while read -r ref; do
    [[ -z "$ref" ]] && continue
    kind=$(echo "$ref" | cut -d: -f1)
    name=$(echo "$ref" | cut -d: -f2)
    # Tentative de résolution du fichier YAML correspondant
    target=$(grep -Rl "kind: $kind" . | xargs grep -l "name: $name" || true)
    for t in $target; do
      rel=$(realpath --relative-to=. "$t" 2>/dev/null || echo "$t")
      refs["$rel"]="$f"
      $DEBUG && echo "🔗 sourceRef $kind/$name -> $rel (via $f)"
    done
  done < <(
    yq eval '
      .. | .spec?.sourceRef? | select(.) |
      (.kind + ":" + .name),
      .. | .spec?.chart?.spec?.sourceRef? | select(.) |
      (.kind + ":" + .name)
    ' "$f" 2>/dev/null | sort -u
  )
done < <(find . -type f -name "*.ya*ml")

echo "────────────────────────────"
for file in $all_files; do
  rel=$(realpath --relative-to=. "$file" 2>/dev/null || echo "$file")

  # Vérif ignore
  skip=false
  for pat in "${ignore_patterns[@]}"; do
    [[ "$rel" =~ $pat ]] && skip=true && $DEBUG && echo "⏩ Ignoré (match .unusedignore): $rel"
  done
  $skip && continue

  if [[ -n "${refs[$rel]:-}" ]]; then
    $DEBUG && echo "✅ Utilisé : $rel (via ${refs[$rel]})"
  else
    echo "❌ Non utilisé : $rel"
  fi
done
