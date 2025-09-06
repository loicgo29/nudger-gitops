#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-.}"

echo "▶️  Running Trivy on ${TARGET}"

# Scan strict pour la CI
trivy config "$TARGET" \
  --severity CRITICAL,HIGH \
  --exit-code 1 \
  --skip-dirs "smoke-tests" \
  --ignorefile .trivyignore

# Génération SARIF (non bloquant)
trivy config "$TARGET" \
  --format sarif \
  --output trivy-k8s.sarif \
  --exit-code 0 \
  --skip-dirs "smoke-tests" \
  --ignorefile .trivyignore
