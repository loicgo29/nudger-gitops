#!/usr/bin/env bash
set -euo pipefail

# Usage:
#  TRIVY_SEVERITY="CRITICAL,HIGH" TRIVY_EXIT_CODE=1 ./scripts/ci-on-pr/trivy.sh go      ./...
#  TRIVY_SEVERITY="CRITICAL,HIGH" TRIVY_EXIT_CODE=1 ./scripts/ci-on-pr/trivy.sh k8s     ./apps
#  TRIVY_SEVERITY="CRITICAL,HIGH" TRIVY_EXIT_CODE=1 ./scripts/ci-on-pr/trivy.sh image   ghcr.io/org/app:tag
#  TRIVY_SEVERITY="CRITICAL,HIGH" TRIVY_EXIT_CODE=1 ./scripts/ci-on-pr/trivy.sh repo    .

CMD="${1:-}"; TARGET="${2:-.}"
SEV="${TRIVY_SEVERITY:-CRITICAL,HIGH}"
EXIT="${TRIVY_EXIT_CODE:-1}"

# Install trivy if missing (useful locally)
if ! command -v trivy >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
fi

case "$CMD" in
  k8s)
    # Scan YAML/Kustomize (misconfig) + secrets
    trivy config \
      --severity "$SEV" --exit-code "$EXIT" \
      --format table \
      --timeout 5m \
      "$TARGET"
    ;;
  image)
    # Scan image conteneur
    trivy image \
      --severity "$SEV" --exit-code "$EXIT" \
      --ignore-unfixed \
      --format table \
      --timeout 10m \
      "$TARGET"
    ;;
  repo)
    # Scan dépôt complet (fallback)
    trivy fs --scanners vuln,secret,config \
      --severity "$SEV" --exit-code "$EXIT" \
      --ignore-unfixed \
      --format table \
      --timeout 10m \
      --skip-dirs vendor --skip-dirs .git \
      "$TARGET"
    ;;
  *)
    echo "Usage: $0 {go|k8s|image|repo} <path|image>" >&2
    exit 2
    ;;
esac
