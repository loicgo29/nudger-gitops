#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:-.}"

echo "▶️ Running Trivy on $TARGET_DIR"

# Install trivy si absent
if ! command -v trivy >/dev/null 2>&1; then
  echo "📦 Installing Trivy..."
  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
    | sh -s -- -b ./bin
  echo "$PWD/bin" >> "$GITHUB_PATH"
fi

trivy --version

# Scan config
trivy config "$1" \
  --exit-code 1 \
  --severity CRITICAL,HIGH \
  --skip-dirs "smoke-tests" \
  --ignorefile .trivyignore

echo "✅ Trivy version : $(trivy --version)"

# Scan des manifests
trivy config "$TARGET_DIR" \
  --severity CRITICAL,HIGH \
  --exit-code 1 \
  --skip-dirs "smoke-tests" \
  --ignorefile .trivyignore || true

# Génération du rapport SARIF quel que soit le résultat
trivy config "$TARGET_DIR" \
  --format sarif \
  --output trivy-k8s.sarif \
  --severity CRITICAL,HIGH \
  --skip-dirs "smoke-tests" \
  --ignorefile .trivyignore || true

ls -lh trivy-k8s.sarif || echo "⚠️ Pas de fichier SARIF généré"
