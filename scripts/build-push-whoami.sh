#!/usr/bin/env bash
set -euo pipefail

# Defaults
REPO="${REPO:-ghcr.io/loicgo29/whoami}"
SEMVER="${SEMVER:-1.11.0}"           # tag SemVer pur pour Flux
SUFFIX="${SUFFIX:-go1.24.6}"         # suffixe informatif
CTX="${CTX:-build/whoami}"           # chemin du Dockerfile/contexte
PLAT="${PLAT:-linux/amd64}"          # plateforme buildx

usage() {
  cat <<USAGE
Usage:
  REPO=ghcr.io/loicgo29/whoami SEMVER=1.11.0 SUFFIX=go1.24.6 CTX=build/whoami $0

Prerequis:
  - docker login ghcr.io (PAT GitHub avec scope "write:packages")
  - docker buildx installé (docker buildx version)

Exemples:
  GHCR_TOKEN=*** docker login ghcr.io -u <ton_github> --password-stdin
  REPO=ghcr.io/loicgo29/whoami SEMVER=1.11.0 SUFFIX=go1.24.6 $0
USAGE
}

if [[ "${1:-}" == "--help" ]]; then usage; exit 0; fi

# Sanity checks
command -v docker >/dev/null || { echo "docker manquant"; exit 1; }
docker buildx version >/dev/null || { echo "docker buildx manquant"; exit 1; }
docker info >/dev/null || { echo "Docker daemon indisponible"; exit 1; }
[[ -d "$CTX" || -f "$CTX/Dockerfile" || -f "$CTX/dockerfile" ]] || { echo "Contexte introuvable: $CTX"; exit 1; }

echo ">> Build & push:"
echo "   repo   : $REPO"
echo "   semver : $SEMVER"
echo "   suffix : $SEMVER-$SUFFIX"
echo "   ctx    : $CTX"
echo "   plat   : $PLAT"

# Build & push deux tags en une fois
docker buildx build --platform "$PLAT" \
  -t "$REPO:$SEMVER" \
  -t "$REPO:$SEMVER-$SUFFIX" \
  --push "$CTX"

echo
echo "OK ✅ Pushed:"
echo " - $REPO:$SEMVER"
echo " - $REPO:$SEMVER-$SUFFIX"

cat <<'NEXT'

Suivi côté Flux (si ton ImageRepository pointe sur ghcr.io/loicgo29/whoami):

1) Forcer un cycle image + policy + update:
   flux reconcile image repository whoami -n flux-system
   kubectl -n flux-system annotate imagepolicy whoami reconcile.fluxcd.io/requestedAt="$(date -u +%Y-%m-%dT%H:%M:%SZ)" --overwrite
   flux reconcile image update whoami-update -n flux-system

2) Vérifier la policy résolue et le déploiement:
   kubectl -n flux-system get imagepolicy whoami -o yaml | yq '.status.latestImage'
   kubectl -n whoami get deploy whoami -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'

Astuce:
- Si tu veux que Flux prenne en compte des tags non-purs (ex: v1.11.0-go1.24.6), mets un filterTags dans ImageRepository qui extrait la partie SemVer,
  sinon publie toujours aussi le tag SemVer pur (ce que fait ce script).
NEXT
