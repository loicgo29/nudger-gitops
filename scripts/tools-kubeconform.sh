#!/usr/bin/env bash
set -euo pipefail

KCONF_VER="${KCONF_VER:-v0.6.7}"

case "$(uname -s)" in
  Linux)  OS="linux" ;;
  Darwin) OS="darwin" ;;
  *) echo "Unsupported OS"; exit 1 ;;
esac

case "$(uname -m)" in
  x86_64|amd64) ARCH="amd64" ;;
  arm64|aarch64) ARCH="arm64" ;;
  *) echo "Unsupported arch"; exit 1 ;;
esac

ASSET="kubeconform-${OS}-${ARCH}.tar.gz"
URL="https://github.com/yannh/kubeconform/releases/download/${KCONF_VER}/${ASSET}"

echo "Downloading ${URL}"
curl -fSL "${URL}" -o kubeconform.tgz
test -s kubeconform.tgz
file kubeconform.tgz | grep -qi 'gzip compressed data'
tar -xzf kubeconform.tgz kubeconform
sudo mv kubeconform /usr/local/bin/kubeconform
kubeconform -v

