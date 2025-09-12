#!/usr/bin/env bash
set -euo pipefail

echo "🧹 Dé-duplication des entrées resources: dans tous les kustomization.yaml"

find . -name 'kustomization.yaml' | while read -r file; do
  echo "🔍 Traitement: $file"
  awk '
    BEGIN { in_resources=0 }
    /^\s*resources:\s*$/ { in_resources=1; print; next }
    /^[^[:space:]]/ { in_resources=0 }
    {
      if (in_resources && seen[$0]++) next;
      print
    }
  ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
done

echo "✅ Dé-duplication terminée."
