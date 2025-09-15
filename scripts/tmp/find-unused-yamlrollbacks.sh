#!/usr/bin/env bash
set -euo pipefail

# Revert les fichiers *.legacy vers leur nom original
find . -type f -name "*.legacy" | while read -r file; do
  orig="${file%.legacy}"
  echo "↩️  Restaure : $file -> $orig"
  mv "$file" "$orig"
done
