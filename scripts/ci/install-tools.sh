#!/usr/bin/env bash
set -euo pipefail

BIN_DIR="${HOME}/.local/bin"
mkdir -p "${BIN_DIR}"
export PATH="${BIN_DIR}:${PATH}"

echo "📦 Installing kubectl..."
KVER=$(curl -sL https://dl.k8s.io/release/stable.txt)
curl -sLo "${BIN_DIR}/kubectl" "https://dl.k8s.io/release/${KVER}/bin/linux/amd64/kubectl"
chmod +x "${BIN_DIR}/kubectl"
kubectl version --client

echo "📦 Installing kustomize..."
# Utiliser le script officiel
curl -sL https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh | bash -s -- "$(pwd)" # installe dans le dossier courant
mv kustomize "${BIN_DIR}/kustomize"
chmod +x "${BIN_DIR}/kustomize"
"${BIN_DIR}/kustomize" version

echo "📦 Installing kubeconform..."
KCF_VER=$(curl -s https://api.github.com/repos/yannh/kubeconform/releases/latest | jq -r .tag_name)
curl -sLo /tmp/kubeconform.tar.gz \
  "https://github.com/yannh/kubeconform/releases/download/${KCF_VER}/kubeconform-linux-amd64.tar.gz"
tar -xzf /tmp/kubeconform.tar.gz -C "${BIN_DIR}" kubeconform
rm /tmp/kubeconform.tar.gz
"${BIN_DIR}/kubeconform" -v

echo "✅ Tools installed in ${BIN_DIR}"
