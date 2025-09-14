#!/usr/bin/env bash
# check-helmrelease.sh
# Vérifie que les HelmRelease déployés dans le cluster correspondent aux manifests Git
# Usage: ./check-helmrelease.sh

set -euo pipefail

# Couleurs
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
RESET=$(tput sgr0)

echo "🔍 Vérification des HelmRelease..."

# Liste des HR dans Git
mapfile -t git_hrs < <(find infra/observability -type f -name '*helmrelease.yaml')

if [[ ${#git_hrs[@]} -eq 0 ]]; then
  echo "${RED}❌ Aucun HelmRelease trouvé dans infra/observability${RESET}"
  exit 1
fi

for file in "${git_hrs[@]}"; do
  name=$(yq '.metadata.name' "$file")
  ns=$(yq '.metadata.namespace' "$file")
  chart=$(yq '.spec.chart.spec.chart' "$file")
  version=$(yq '.spec.chart.spec.version' "$file")

  echo "➡️  $ns/$name (chart=$chart, version=$version)"

  # Récupère le HR du cluster
  if ! kubectl -n "$ns" get helmrelease "$name" >/dev/null 2>&1; then
    echo "   ${RED}✗ Absent du cluster${RESET}"
    continue
  fi

  cluster_version=$(kubectl -n "$ns" get hr "$name" -o jsonpath='{.spec.chart.spec.version}')
  cluster_chart=$(kubectl -n "$ns" get hr "$name" -o jsonpath='{.spec.chart.spec.chart}')

  if [[ "$cluster_chart" != "$chart" ]]; then
    echo "   ${RED}✗ Chart différent${RESET} (Git=$chart / Cluster=$cluster_chart)"
  elif [[ "$cluster_version" != "$version" ]]; then
    echo "   ${YELLOW}! Version différente${RESET} (Git=$version / Cluster=$cluster_version)"
  else
    echo "   ${GREEN}✓ Conforme${RESET}"
  fi
done
