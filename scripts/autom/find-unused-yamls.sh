#!/usr/bin/env bash
set -euo pipefail

echo "🔍 Recherche des YAML non utilisés dans les kustomizations..."

# 1. Tous les fichiers .yaml ou .yml (hors .git, scripts, README, etc.)
all_files=$(find . -type f \( -name "*.yaml" -o -name "*.yml" \) \
  ! -path "./.git/*" \
  ! -path "./scripts/*" \
  ! -name "kustomization.yaml" \
  ! -name "kustomization.yml")

# 2. Références dans les kustomizations
used_files=$(grep -R "resources:" -A10 . | grep -v "kustomization" | awk '{print $2}' | sed 's|"||g;s|'\''||g' | sort -u)

# 3. Normaliser les chemins relatifs (ex: ./infra/…)
normalize() {
  realpath --relative-to=. "$1" 2>/dev/null || echo "$1"
}

echo "────────────────────────────"
for file in $all_files; do
  rel=$(normalize "$file")
  if ! grep -qx "$rel" <(echo "$used_files"); then
    echo "❌ Non utilisé : $rel"
  fi
done
