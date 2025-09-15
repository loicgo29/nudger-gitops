#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-.}"

echo "🔧 Auto-fix des Namespace (prefixe ns-) dans $ROOT_DIR"
echo

find "$ROOT_DIR" -type f \( -name "*.yaml" -o -name "*.yml" \) \
  ! -path "*/dump/*" | while read -r file; do
  echo "👉 Analyse de $file"
  kind=$(yq e '.kind' "$file" 2>/dev/null || true)
  name=$(yq e '.metadata.name' "$file" 2>/dev/null || true)

  if [[ "$kind" == "Namespace" && -n "$name" && "$name" != null ]]; then
    if [[ "$name" != ns-* ]]; then
      new_name="ns-$name"
      echo "⚠️  [$file] Namespace '$name' → '$new_name'"

      yq e -i ".metadata.name = \"$new_name\"" "$file"

      grep -rl "namespace: $name" "$ROOT_DIR" --include="*.yaml" --include="*.yml" \
        | grep -v "/dump/" | while read -r ref_file; do
        echo "   ↳ mise à jour référence dans $ref_file"
        sed -i "s/namespace: $name/namespace: $new_name/g" "$ref_file"
      done
    else
      echo "✅ [$file] Namespace déjà correct: $name"
    fi
  fi
done

echo
echo "✅ Auto-fix terminé."
