#!/usr/bin/env bash
# ./scripts/lint/check-helmrelease-chart.sh

echo "🔍 Vérification des références de chart HelmRelease..."

ERRORS=0

while IFS= read -r file; do
  chart=$(yq '.spec.chart.spec.chart' "$file")
  if [[ "$chart" != */* ]]; then
    echo "❌ $file → chart mal formé : '$chart' (manque 'repo/chartname')"
    ERRORS=1
  fi
done < <(grep -rl 'kind: HelmRelease' ./infra)

exit $ERRORS
