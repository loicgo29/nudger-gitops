#!/usr/bin/env bash
set -euo pipefail
APPLY=false
if [[ "${1:-}" == "--apply" ]]; then
  APPLY=true
fi

echo "APPLY=$APPLY"

for file in $(grep -Rl "kind:" ./apps ./infra ./clusters ./flux-system --include="*.yaml" --include="*.yml"); do
  kind=$(grep -m1 "^kind:" "$file" | awk '{print $2}')
  name=$(grep -m1 "name:" "$file" | awk '{print $2}' || true)

  # skip si pas de name
  if [[ -z "${name}" ]]; then
    continue
  fi

  case "$kind" in
    HelmRelease)    prefix="helm-" ;;
    HelmRepository) prefix="helmrepo-" ;;
    GitRepository)  prefix="gitrepo-" ;;
    Kustomization)  prefix="meta-" ;;
    ConfigMap)      prefix="cfg-" ;;
    Secret)         prefix="sec-" ;;
    Namespace)      prefix="ns-" ;;
    ServiceMonitor) prefix="sm-" ;;
    *)              prefix="" ;;
  esac

  if [[ -n "$prefix" && "$name" != $prefix* ]]; then
    new="$prefix$name"
    if [[ "$APPLY" == "true" ]]; then
      echo "✍️ [$file] $kind: $name → $new"
      sed -i "s/\(name:\s*\)$name/\1$new/" "$file"
    else
      echo "❌ [$file] $kind → $name doit devenir $new"
    fi
  else
    echo "✅ [$file] $kind: $name (ok)"
  fi
done
