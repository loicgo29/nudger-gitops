#!/usr/bin/env bash
set -euo pipefail

REPORT="unused-report.txt"   # rapport avec les lignes "❌ Non utilisé : chemin"
ROOT_DIR="."                 # racine du repo

grep "❌ Non utilisé" "$REPORT" | sed 's/.*❌ Non utilisé : //' | while read -r filepath; do
  if [ -f "$ROOT_DIR/$filepath" ]; then
    newpath="${ROOT_DIR}/${filepath}.legacy"
    echo "🔄 Renommage : $filepath -> $newpath"
    mv "$ROOT_DIR/$filepath" "$newpath"
  else
    echo "⚠️  Fichier introuvable : $filepath"
  fi
done
