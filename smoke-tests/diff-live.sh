#!/usr/bin/env bash
set -euo pipefail
set -x

ROOT="${1:-.}"
shift || true

echo "── Scan des manifests dans: $ROOT ─────────────────────────────"

TOTAL=0
while read -r f; do
  echo "📂 Fichier: $f"
  if grep -q '^apiVersion:' "$f"; then
    echo "✅ Manifeste détecté"
    TOTAL=$((TOTAL+1))
    yq e '.kind + "/" + .metadata.name' "$f" || true
  else
    echo "❌ Pas un manifeste K8s"
  fi
done < <(find "$ROOT" -type f \( -name '*.yaml' -o -name '*.yml' -o -name '*.json' \) ! -path '*/.git/*' -print)

echo
echo "── Résumé ─────────────────────────────"
echo "📄 Docs trouvés: $TOTAL"
