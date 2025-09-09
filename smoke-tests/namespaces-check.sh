#!/usr/bin/env bash
set -euo pipefail

expected_ns=("open4goods-prod" "open4goods-integration" "open4goods-recette" "observability")
declare -A env_map=(
  ["open4goods-prod"]="prod"
  ["open4goods-integration"]="integration"
  ["open4goods-recette"]="recette"
  ["observability"]="observability"
)

echo "==> Présence + labels environment"
kubectl get ns -L environment | sed '1,1!b' >/dev/null # force headers

for ns in "${expected_ns[@]}"; do
  if ! kubectl get ns "$ns" >/dev/null 2>&1; then
    echo "KO: namespace manquant: $ns"; exit 1
  fi
  envv=$(kubectl get ns "$ns" -o jsonpath='{.metadata.labels.environment}')
  if [[ "$envv" != "${env_map[$ns]}" ]]; then
    echo "KO: environment attendu=${env_map[$ns]} trouvé=$envv pour $ns"; exit 1
  fi
done

echo "==> PSA labels"
for ns in "${expected_ns[@]}"; do
  for k in enforce warn audit; do
    v=$(kubectl get ns "$ns" -o jsonpath="{.metadata.labels.pod-security\.kubernetes\.io/$k}")
    [[ "$v" == "baseline" ]] || { echo "KO: PSA $k != baseline sur $ns"; exit 1; }
  done
done

echo "OK: Namespaces + labels PSA conformes."
