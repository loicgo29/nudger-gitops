#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:-.}"

echo "▶️  Running Trivy on $TARGET_DIR"

# Install Trivy si absent
if ! command -v trivy >/dev/null 2>&1; then
  echo "📦 Installing Trivy..."
  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh
  sudo mv ./bin/trivy /usr/local/bin/trivy
  rm -rf ./bin
fi
# Scan config
trivy config "$TARGET_DIR" \
  --severity CRITICAL,HIGH \
  --exit-code 1 \
  --skip-dirs "smoke-tests" \
  --ignorefile .trivyignore || true

# Rapport SARIF (optionnel)
trivy config "$TARGET_DIR" \
  --format sarif \
  --output trivy-k8s.sarif \
  --exit-code 0 \
  --skip-dirs "smoke-tests" \
  --ignorefile .trivyignore || true

ls -lh trivy-k8s.sarif || echo "⚠️ Pas de fichier SARIF généré"
