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
  images-in-apps)
  CONCURRENCY="${CONCURRENCY:-4}"

  # 1) Rendre tous les kustomize sous $TARGET, extraire UNIQUEMENT les champs .image (strings)
  IMAGES=$(
    find "$TARGET" -name kustomization.yaml -printf '%h\n' \
    | sort -u \
    | while read -r d; do kustomize build "$d"; done \
    | yq -o=json '.' \
    | jq -r '
        # On ne garde que les specs de Pod (direct) ou de template (workloads)
        if .kind == "Pod" then [.spec]
        elif (.spec // empty) and (.spec.template // empty) and (.spec.template.spec // empty) then [.spec.template.spec]
        elif (.spec // empty) and (.spec.jobTemplate // empty) and (.spec.jobTemplate.spec.template // empty) then [.spec.jobTemplate.spec.template.spec]  # CronJob
        else [] end
        | .[]
        | ((.containers // []) + (.initContainers // []))
        | .[]?.image
      ' 2>/dev/null \
    | awk 'NF' \
    | sort -u
  )

  if [ -z "$IMAGES" ]; then
    echo "No images found under $TARGET"
    exit 0
  fi

  # 2) Filtrer les valeurs plausibles d’images (tag ou digest, multi-registry ok)
  VALID_IMAGES=$(echo "$IMAGES" | grep -E '^[A-Za-z0-9._/-]+(:[A-Za-z0-9._.-]+)?(@sha256:[a-f0-9]{64})?$' || true)
  if [ -z "$VALID_IMAGES" ]; then
    echo "No valid image references found"
    exit 0
  fi

  # 3) Scanner en parallèle
  echo "$VALID_IMAGES" | xargs -P "$CONCURRENCY" -I{} sh -c '
    echo "==> trivy image {}"
    trivy image --severity "'"$SEV"'" --exit-code "'"$EXIT"'" --ignore-unfixed --timeout 10m --format table "{}"
  '
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
