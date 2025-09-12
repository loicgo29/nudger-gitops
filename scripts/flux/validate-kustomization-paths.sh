#!/bin/bash
# validate-kustomization-paths.sh

set -euo pipefail

find . -name 'kustomization.yaml' | while read -r file; do
  echo "🧪 Vérification: $file"
  DIR=$(dirname "$file")
  grep '^- ' "$file" | sed 's/- //' | while read -r resource; do
    [[ "$resource" =~ ^http ]] && continue
    path="$DIR/$resource"
    if [[ ! -e "$path" ]]; then
      echo "❌ Manquant: $path"
    fi
  done
done
