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

declare -A refs

# Fonction récursive : marque tous les resources d’un kustomization comme utilisés
mark_kustomization() {
  local kf="$1"
  [[ ! -f "$kf" ]] && return
  local dir
  dir=$(dirname "$kf")

  # Récupère les ressources/patches/patchesStrategicMerge
  while read -r ref; do
    [[ -z "$ref" || "$ref" == "null" ]] && continue
    local child="$dir/$ref"
    child=$(realpath --relative-to=. "$child" 2>/dev/null || echo "$child")

    refs["$child"]="$kf"

    # Si le child est lui-même un kustomization.yaml → descendre récursivement
    if grep -q "kind: Kustomization" "$child" 2>/dev/null; then
      mark_kustomization "$child"
    fi
  done < <(yq eval '.resources[]?, .patches[]?.path?, .patchesStrategicMerge[]?' "$kf" 2>/dev/null || true)
}

# Indexation des références
while IFS= read -r -d '' f; do
  kind=$(yq eval '.kind' "$f" 2>/dev/null || echo "")
  case "$kind" in
    Kustomization)
      mark_kustomization "$f"
      ;;
    HelmRelease)
      src=$(yq eval '.spec.chart.spec.sourceRef.name' "$f" 2>/dev/null || echo "")
      [[ -n "$src" && "$src" != "null" ]] && refs["$src.yaml"]="$f"
      ;;
    GitRepository|HelmRepository|ImageRepository|ImagePolicy|ImageUpdateAutomation)
      # Considérés comme utilisés seulement si un parent les référence
      :
      ;;
  esac
done < <(find . -type f -name '*.yaml' -print0)

# Vérifie l’usage de chaque fichier YAML
while IFS= read -r -d '' f; do
  rel=$(realpath --relative-to=. "$f")
  for ig in "${IGNORES[@]}"; do
    if [[ "$rel" == $ig || "$rel" == $ig/* ]]; then
      continue 2
    fi
  done

  if [[ -n "${refs[$rel]:-}" ]]; then
    continue # utilisé → on ne dit rien
  else
    echo "❌ Non utilisé : $rel"
  fi
done < <(find . -type f -name '*.yaml' -print0)
