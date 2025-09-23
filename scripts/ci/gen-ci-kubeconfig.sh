#!/bin/bash
set -euo pipefail

NS="flux-system"
SA="ci-runner"
SECRET="${SA}-token"

# Récupération des infos cluster
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CA=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
TOKEN=$(kubectl -n "$NS" get secret "$SECRET" -o jsonpath='{.data.token}' | base64 -d)

OUT="kubeconfig-ci.yaml"

cat > "$OUT" <<EOF
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

echo "✅ Kubeconfig écrit dans $OUT"

# Génère aussi la version base64 (pratique pour secrets GitHub)
cat "$OUT" | base64 -w0 > kubeconfig-ci.b64
echo
echo "✅ Fichier base64 dispo dans kubeconfig-ci.b64"
