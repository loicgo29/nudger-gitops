#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-.}"

echo "🔍 Vérification des chemins de ressources dans les kustomization.yaml"
echo "📂 Racine : $ROOT_DIR"
echo

# Trouver tous les fichiers kustomization.yaml
find "$ROOT_DIR" -type f \( -name "kustomization.yaml" -o -name "kustomization.yml" -o -name "Kustomization" \) | while read -r kfile; do
  echo "────────────────────────────"
  echo "📄 $kfile"

  # Extraire les chemins définis sous "resources:"
  resources=$(yq e '.resources[]' "$kfile" 2>/dev/null || true)

  if [[ -z "$resources" ]]; then
    echo "⚠️  Aucun resources trouvé dans $kfile"
    continue
  fi

  base_dir="$(dirname "$kfile")"

  while IFS= read -r res; do
    # Skip si null/empty
    [[ "$res" == "null" ]] && continue

    target="$base_dir/$res"
    if [[ -e "$target" ]]; then
      echo "  ✅ $res existe"
    else
      echo "  ❌ $res manquant → $target"
    fi
  done <<< "$resources"

done
