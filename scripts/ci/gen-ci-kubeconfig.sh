#!/bin/bash
set -euo pipefail

NS="flux-system"
SA="ci-runner"

echo "🔑 Génération du kubeconfig CI pour ServiceAccount ${SA} (${NS})..."

SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CA=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
TOKEN=$(kubectl -n "$NS" get secret $(kubectl -n "$NS" get sa "$SA" -o jsonpath='{.secrets[0].name}') -o jsonpath='{.data.token}' | base64 -d)

cat <<EOF > kubeconfig-ci.yaml
apiVersion: v1
kind: Config
clusters:
- name: nudger
  cluster:
    certificate-authority-data: ${CA}
    server: ${SERVER}
contexts:
- name: nudger
  context:
    cluster: nudger
    namespace: ns-open4goods-recette
    user: ${SA}
current-context: nudger
users:
- name: ${SA}
  user:
    token: ${TOKEN}
EOF

echo "✅ kubeconfig écrit dans kubeconfig-ci.yaml"

# Générer la version base64 directement pour GitHub Actions
base64 -w0 kubeconfig-ci.yaml > kubeconfig-ci.b64
echo "✅ kubeconfig-ci.b64 généré (prêt pour gh secret set KUBECONFIG_B64 < kubeconfig-ci.b64)"

echo ""
echo "👉 Étape suivante :"
echo "   gh secret set KUBECONFIG_B64 < kubeconfig-ci.b64"
