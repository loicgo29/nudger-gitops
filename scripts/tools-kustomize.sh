#!/usr/bin/env bash
set -euo pipefail

KVER="${KVER:-v5.4.2}"

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"  # linux|darwin
ARCH_RAW="$(uname -m)"
case "${ARCH_RAW}" in
  x86_64|amd64) ARCH="amd64" ;;
  arm64|aarch64) ARCH="arm64" ;;
  *) echo "Unsupported arch: ${ARCH_RAW}"; exit 1 ;;
esac

BASE="https://github.com/kubernetes-sigs/kustomize/releases/download"
TAG="kustomize%2F${KVER}"  # <— slash encodé !
ASSET="kustomize_${KVER#v}_${OS}_${ARCH}.tar.gz"
URL="${BASE}/${TAG}/${ASSET}"

echo "Downloading ${URL}"
curl -fSL "${URL}" -o kustomize.tgz
test -s kustomize.tgz
file kustomize.tgz | grep -qi 'gzip compressed data'
tar -xzf kustomize.tgz
sudo mv kustomize /usr/local/bin/kustomize
kustomize version

