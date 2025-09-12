#!/usr/bin/env bash
set -euo pipefail

# 🔧 Paramètres
NAMESPACE="observability"
CONFIGMAP_NAME="dashboard-policy-reporter"
DASHBOARD_UID="14858"
DASHBOARD_URL="https://grafana.com/api/dashboards/${DASHBOARD_UID}/revisions/latest/download"
OUTPUT_FILE="infra/observability/dashboard/policy-reporter-dashboard.yaml"

# 🔽 Téléchargement du dashboard brut
echo "📥 Téléchargement du dashboard Grafana ID ${DASHBOARD_UID}..."
RAW_JSON=$(curl -fsSL "$DASHBOARD_URL")

# 🔁 Remplacement de la variable non résolue
echo "🔧 Remplacement de la variable \${mydatasource} → \"Prometheus\""
CLEANED_JSON=$(echo "$RAW_JSON" | sed 's/\${mydatasource}/Prometheus/g')

# 📦 Génération de la ConfigMap Kubernetes
echo "🛠 Génération du fichier YAML : $OUTPUT_FILE"
mkdir -p "$(dirname "$OUTPUT_FILE")"
cat <<EOF > "$OUTPUT_FILE"
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${CONFIGMAP_NAME}
  namespace: ${NAMESPACE}
  labels:
    grafana_dashboard: "1"
data:
  policy-reporter.json: |
$(echo "$CLEANED_JSON" | jq -c '.' | sed 's/^/    /')
EOF

echo "✅ Dashboard prêt à être appliqué avec Kustomize ou kubectl."
