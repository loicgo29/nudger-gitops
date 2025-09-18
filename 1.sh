#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="infra/action-runner-controller/runners"
REPO="loicgo29/nudger-gitops"

mkdir -p ${BASE_DIR}/{integration,recette,prod}

##############################################
# Integration
##############################################
cat <<'EOF' > ${BASE_DIR}/integration/runnerdeployment-nudger-gitops-integration.yaml
apiVersion: actions.summerwind.dev/v1alpha1
kind: RunnerDeployment
metadata:
  name: nudger-gitops-integration-runner
  namespace: ns-open4goods-integration
spec:
  replicas: 1
  template:
    spec:
      repository: loicgo29/nudger-gitops
      labels:
        - self-hosted
        - nudger
        - integration
      envFrom:
        - secretRef:
            name: controller-manager
EOF

cat <<'EOF' > ${BASE_DIR}/integration/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - runnerdeployment-nudger-gitops-integration.yaml
EOF

##############################################
# Recette
##############################################
cat <<'EOF' > ${BASE_DIR}/recette/runnerdeployment-nudger-gitops-recette.yaml
apiVersion: actions.summerwind.dev/v1alpha1
kind: RunnerDeployment
metadata:
  name: nudger-gitops-recette-runner
  namespace: ns-open4goods-recette
spec:
  replicas: 1
  template:
    spec:
      repository: loicgo29/nudger-gitops
      labels:
        - self-hosted
        - nudger
        - recette
      envFrom:
        - secretRef:
            name: controller-manager
EOF

cat <<'EOF' > ${BASE_DIR}/recette/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - runnerdeployment-nudger-gitops-recette.yaml
EOF

##############################################
# Production
##############################################
cat <<'EOF' > ${BASE_DIR}/prod/runnerdeployment-nudger-gitops-prod.yaml
apiVersion: actions.summerwind.dev/v1alpha1
kind: RunnerDeployment
metadata:
  name: nudger-gitops-prod-runner
  namespace: ns-open4goods-prod
spec:
  replicas: 1
  template:
    spec:
      repository: loicgo29/nudger-gitops
      labels:
        - self-hosted
        - nudger
        - prod
      envFrom:
        - secretRef:
            name: controller-manager
EOF

cat <<'EOF' > ${BASE_DIR}/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - runnerdeployment-nudger-gitops-prod.yaml
EOF

echo "✅ RunnerDeployments et Kustomizations générés dans ${BASE_DIR}/{integration,recette,prod}"
