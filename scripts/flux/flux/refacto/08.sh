#!/usr/bin/env bash
set -euo pipefail

RELEASES=(promtail loki policy-reporter)

for NAME in "${RELEASES[@]}"; do
  SRC="infra/observability/base/helmrelease-${NAME}.yaml"
  DEST="infra/observability/releases/${NAME}"

  echo "📦 Refactor: $SRC → $DEST/helmrelease.yaml"
  
  if [[ -f "$SRC" ]]; then
    mkdir -p "$DEST"
    mv "$SRC" "$DEST/helmrelease.yaml"
    cat <<EOF > "$DEST/kustomization.yaml"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - helmrelease.yaml
EOF
  else
    echo "⚠️  $SRC not found"
  fi
done

echo "🔧 Mise à jour des références dans les kustomization.yaml..."
find . -name 'kustomization.yaml' \
  -exec sed -i "s|../../observability/base/helmrelease-promtail.yaml|../../observability/releases/promtail|g" {} +
find . -name 'kustomization.yaml' \
  -exec sed -i "s|../../observability/base/helmrelease-loki.yaml|../../observability/releases/loki|g" {} +
find . -name 'kustomization.yaml' \
  -exec sed -i "s|../../observability/base/helmrelease-policy-reporter.yaml|../../observability/releases/policy-reporter|g" {} +
