#!/usr/bin/env bash
set -euo pipefail

echo "🔧 [APPLY] Correction automatique des préfixes..."

declare -A PREFIX_MAP=(
  ["HelmRelease"]="helm-"
  ["HelmRepository"]="helmrepo-"
  ["GitRepository"]="gitrepo-"
  ["ServiceMonitor"]="sm-"
  ["ConfigMap"]="cfg-"
  ["Secret"]="sec-"
  ["Namespace"]="ns-"
)

get_kustomization_prefix() {
  local file="$1"
  case "$file" in
    *apps/*) echo "apps-" ;;
    *infra/*) echo "infra-" ;;
    *kyverno/*) echo "kyverno-" ;;
    *clusters/*) echo "meta-" ;;
    *) echo "ks-" ;;
  esac
}

find ./ -type f \( -name "*.yaml" -o -name "*.yml" \) | while read -r file; do
  kind=$(yq e '.kind' "$file" 2>/dev/null || true)
  name=$(yq e '.metadata.name' "$file" 2>/dev/null || true)

  [[ -z "$kind" || -z "$name" || "$kind" == "null" || "$name" == "null" ]] && continue

  if [[ "$kind" == "Kustomization" ]]; then
    prefix=$(get_kustomization_prefix "$file")
  else
    prefix="${PREFIX_MAP[$kind]:-}"
  fi

  if [[ -n "$prefix" && ! "$name" =~ ^$prefix ]]; then
    new_name="${prefix}${name}"
    echo "✏️ [$file] $kind: $name → $new_name"
    yq e -i ".metadata.name = \"$new_name\"" "$file"
  fi
done

echo "✅ [APPLY] Tous les fichiers ont été corrigés."
