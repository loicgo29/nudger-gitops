#!/usr/bin/env bash
set -euxo pipefail

ROOT_DIR="${1:-$HOME/nudger-gitops}"
TMP_ERRORS=$(mktemp)
trap 'rm -f "$TMP_ERRORS"' EXIT

# Règles de préfixes par kind
RULES=(
  "HelmRelease=helm-"
  "Kustomization=apps- infra- meta- kyverno-"
  "HelmRepository=helmrepo-"
  "GitRepository=gitrepo-"
  "Namespace=ns-"
  "ServiceMonitor=sm-"
  "PrometheusRule=rule-"
  "AlertmanagerConfig=amcfg-"
  "ClusterPolicy=kyverno-"
  "ClusterRole=rbac-"
  "ClusterRoleBinding=rbac-"
  "ConfigMap=cfg-"
  "Secret=sec-"
)

# Scan tous les fichiers YAML
find "$ROOT_DIR" -type f \( -name '*.yaml' -o -name '*.yml' \) | while read -r file; do
  kind=$(yq e '.kind' "$file" 2>/dev/null || true)
  name=$(yq e '.metadata.name' "$file" 2>/dev/null || true)

  [[ -z "$kind" || -z "$name" || "$kind" == "null" || "$name" == "null" ]] && continue

  for rule in "${RULES[@]}"; do
    rule_kind="${rule%%=*}"
    prefixes="${rule#*=}"

    if [[ "$kind" == "$rule_kind" ]]; then
      valid=false
      for p in $prefixes; do
        [[ "$name" == "$p"* ]] && valid=true && break
      done

      if [[ "$valid" == false ]]; then
        echo "❌ [$file] $kind → '$name' n'a pas de préfixe valide parmi: $prefixes" >> "$TMP_ERRORS"
      fi
    fi
  done
done

# Affichage final
if [[ -s "$TMP_ERRORS" ]]; then
  cat "$TMP_ERRORS"
  exit 1
else
  echo "✅ Tous les noms de ressources respectent les conventions de préfixes."
fi
