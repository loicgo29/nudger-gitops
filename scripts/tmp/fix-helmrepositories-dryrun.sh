#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-.}"
DRY_RUN=true

# si --apply est passé => on applique vraiment
if [[ "${2:-}" == "--apply" ]]; then
  DRY_RUN=false
fi

echo "🔧 Scan des HelmRepository (prefixe helmrepo-) dans $ROOT_DIR"
TMP_ERRORS=$(mktemp)
trap 'rm -f "$TMP_ERRORS"' EXIT

find "$ROOT_DIR" -type f -name '*.yaml' | while read -r file; do
  kind=$(yq e '.kind' "$file" 2>/dev/null || true)
  name=$(yq e '.metadata.name' "$file" 2>/dev/null || true)

  [[ "$kind" != "HelmRepository" || -z "$name" || "$name" == "null" ]] && continue

  # attendu : prefixe helmrepo-
  if [[ ! "$name" =~ ^helmrepo- ]]; then
    new_name="helmrepo-$name"

    echo "❌ [$file] HelmRepository → '$name' doit être '$new_name'"

    if ! $DRY_RUN; then
      # check si le nouveau nom existe déjà dans un autre fichier
      if grep -R "name: $new_name" "$ROOT_DIR" | grep -v "$file" >/dev/null; then
        echo "⚠️  Conflit: '$new_name' existe déjà ailleurs, skip."
        continue
      fi

      # patch dans le fichier courant
      yq e -i ".metadata.name = \"$new_name\"" "$file"
      echo "✅ Corrigé dans $file → $new_name"
    fi
  fi
done

if $DRY_RUN; then
  echo "👀 Dry-run terminé (ajoute --apply pour corriger)."
fi
