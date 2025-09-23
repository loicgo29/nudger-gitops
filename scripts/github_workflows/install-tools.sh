#!/usr/bin/env bash
set -euo pipefail

BIN_DIR="${HOME}/.local/bin"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"

echo "🔧 Installing common tools..."

# yq
if ! command -v yq >/dev/null 2>&1; then
  YQ_VER="v4.44.3"
  curl -fsSL -o "${BIN_DIR}/yq" "https://github.com/mikefarah/yq/releases/download/${YQ_VER}/yq_linux_amd64"
  chmod +x "${BIN_DIR}/yq"
fi
yq --version

# kustomize
if [[ "${INSTALL_KUSTOMIZE:-0}" == "1" ]]; then
  KVER="5.4.2"
  curl -fsSL -o /tmp/kustomize.tgz "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KVER}/kustomize_v${KVER}_linux_amd64.tar.gz"
  tar -xzf /tmp/kustomize.tgz -C /tmp kustomize
  mv /tmp/kustomize "${BIN_DIR}/kustomize"
  kustomize version
fi

# kubeconform
if [[ "${INSTALL_KUBECONFORM:-0}" == "1" ]]; then
  KCF="0.6.7"
  curl -fsSL -o /tmp/kc.tgz "https://github.com/yannh/kubeconform/releases/download/v${KCF}/kubeconform-linux-amd64.tar.gz"
  tar -xzf /tmp/kc.tgz -C /tmp kubeconform
  mv /tmp/kubeconform "${BIN_DIR}/kubeconform"
  kubeconform -v
fi

echo "✅ Tools installed in $BIN_DIR"
