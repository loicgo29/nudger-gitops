#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-.}"

echo "🔍 Dry-run auto-fix des HelmRepository (prefixe helmrepo-) dans $ROOT_DIR"
echo

# Parcourt tous les fichiers YAML
find "$ROOT_DIR" -type f \( -name "*.yaml" -o -name "*.yml" \) \
  ! -path "*/dump/*" | while read -r file; do
  kind=$(yq e '.kind' "$file" 2>/dev/null || true)
  name=$(yq e '.metadata.name' "$file" 2>/dev/null || true)

  if [[ "$kind" == "HelmRepository" && -n "$name" && "$name" != null ]]; then
    if [[ "$name" != helmrepo-* ]]; then
      new_name="helmrepo-$name"
      echo "⚠️  [$file] HelmRepository '$name' → '$new_name'"

      # Affiche les références qui devraient être mises à jour
      grep -rl "name: $name" "$ROOT_DIR" --include="*.yaml" --include="*.yml" \
        | grep -v "/dump/" | while read -r ref_file; do
        if grep -q "sourceRef:" "$ref_file"; then
          echo "   ↳ (dry-run) référence trouvée dans $ref_file"
        fi
      done
    else
      echo "✅ [$file] HelmRepository déjà correct: $name"
    fi
  fi
done

echo
echo "✅ Dry-run terminé (aucune modification appliquée)."
