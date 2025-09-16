#!/usr/bin/env bash
set -euo pipefail

unusedignore="$HOME/nudger-gitops/scripts/autom/.unusedignore"
IGNORES=()
if [[ -f "$unusedignore" ]]; then
  echo "📂 Fichiers ignorés depuis $unusedignore"
  mapfile -t IGNORES < "$unusedignore"
fi

echo "🔍 Recherche des YAML non utilisés dans les kustomizations..."
echo "────────────────────────────"

declare -A used_files

mark_used() {
  local target="$1"
  local origin="$2"
  if [[ -f "$target" ]]; then
    rel=$(realpath --relative-to=. "$target")
    used_files["$rel"]="$origin"
  fi
}

# Cherche toutes les kustomization.yaml/yml
kustom_files=$(find ./ -type f \( -name "kustomization.yaml" -o -name "kustomization.yml" \))

for kfile in $kustom_files; do
  base_dir=$(dirname "$kfile")
  resources=$(yq e '.resources[]?, .patches[]?.path?, .patchesStrategicMerge[]?' "$kfile" 2>/dev/null || true)

  for res in $resources; do
    res_path="$base_dir/$res"
    if [[ -d "$res_path" ]]; then
      while IFS= read -r f; do
        rel=$(realpath --relative-to=. "$f")
        used_files["$rel"]="$kfile"
      done < <(find "$res_path" -type f \( -name "*.yaml" -o -name "*.yml" \))
    else
      rel=$(realpath --relative-to=. "$res_path" 2>/dev/null || echo "$res_path")
      used_files["$rel"]="$kfile"
    fi
  done
done

# Parcourt tous les YAML pour trouver des sourceRef
while IFS= read -r -d '' f; do
  kind=$(yq e '.kind' "$f" 2>/dev/null || echo "")

  case "$kind" in
    Kustomization|HelmRelease)
      src_name=$(yq e '.spec.sourceRef.name' "$f" 2>/dev/null || echo "")
      [[ -n "$src_name" && "$src_name" != "null" ]] && mark_used "$(dirname "$f")/${src_name}.yaml" "$f"

      chart_src=$(yq e '.spec.chart.spec.sourceRef.name' "$f" 2>/dev/null || echo "")
      [[ -n "$chart_src" && "$chart_src" != "null" ]] && mark_used "$(dirname "$f")/${chart_src}.yaml" "$f"
      ;;
  esac
done < <(find . -type f -name '*.yaml' -print0)

# Vérifie l’usage de chaque fichier YAML
while IFS= read -r -d '' f; do
  rel=$(realpath --relative-to=. "$f")

  # Ignore les kustomization.*
  [[ "$(basename "$rel")" =~ ^kustomization\.ya?ml$ ]] && continue

  # Ignore patterns de .unusedignore
  for ig in "${IGNORES[@]}"; do
    if [[ "$rel" == $ig || "$rel" == $ig/* ]]; then
      continue 2
    fi
  done

  # Affiche uniquement les non utilisés
  [[ -z "${used_files[$rel]:-}" ]] && echo "❌ Non utilisé : $rel"
done < <(find . -type f -name '*.yaml' -print0)
