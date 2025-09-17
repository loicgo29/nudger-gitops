#!/usr/bin/env bash
set -euo pipefail

expected_ns=("open4goods-prod" "open4goods-integration" "open4goods-recette" "observability")
declare -A env_map=(
  ["open4goods-prod"]="prod"
  ["open4goods-integration"]="integration"
  ["open4goods-recette"]="recette"
  ["observability"]="observability"
)

declare -A psa_map=(
  ["open4goods-prod"]="restricted"
  ["open4goods-integration"]="baseline"
  ["open4goods-recette"]="baseline"
  ["observability"]="baseline"
)

echo "==> Vérification des namespaces et labels"

for ns in "${expected_ns[@]}"; do
  echo "--> Namespace: $ns"

  # Vérifie que le namespace existe
  if ! kubectl get ns "$ns" >/dev/null 2>&1; then
    echo "❌ KO: namespace manquant: $ns"
    exit 1
  fi

  # Vérifie le label `environment`
  env_actual=$(kubectl get ns "$ns" -o jsonpath='{.metadata.labels.environment}')
  env_expected="${env_map[$ns]}"
  if [[ "$env_actual" != "$env_expected" ]]; then
    echo "❌ KO: label environment attendu=$env_expected, trouvé=$env_actual pour $ns"
    exit 1
  fi
  echo "✅ label environment = $env_actual"

  # Vérifie les PSA (baseline ou restricted selon le namespace)
  psa_expected="${psa_map[$ns]}"
  for k in enforce warn audit; do
    v=$(kubectl get ns "$ns" -o jsonpath="{.metadata.labels.pod-security\.kubernetes\.io/$k}")
    if [[ "$v" != "$psa_expected" ]]; then
      echo "❌ KO: PSA $k attendu=$psa_expected, trouvé=$v pour $ns"
      exit 1
    fi
  done
  echo "✅ PSA = $psa_expected (enforce/warn/audit)"
done

echo
echo "🎉 OK: Tous les namespaces sont présents, labellisés, et conformes à la politique PSA attendue."
