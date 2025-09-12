#!/usr/bin/env bash
set -euo pipefail

# 🔧 Paramètres
DASHBOARD_URL="${1:-https://grafana.com/api/dashboards/14858/revisions/1/download}"
DASHBOARD_NAME="${2:-policy-reporter}"
NAMESPACE="${3:-observability}"
FOLDER="infra/observability/dashboard"
OUT_FILE="$FOLDER/${DASHBOARD_NAME//_/-}-dashboard.yaml"

# 📥 Télécharger le JSON
echo "📥 Téléchargement du dashboard depuis : $DASHBOARD_URL"
JSON=$(curl -fsSL "$DASHBOARD_URL")

# 📦 Construction du ConfigMap
echo "📦 Génération du fichier YAML : $OUT_FILE"
cat > "$OUT_FILE" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: dashboard-${DASHBOARD_NAME//_/-}
  namespace: $NAMESPACE
  labels:
    grafana_dashboard: "1"
data:
  ${DASHBOARD_NAME}.json: |
$(echo "$JSON" | jq -c '.' | sed 's/^/    /')
EOF

# 📂 Vérification
echo "✅ Dashboard ajouté à: $OUT_FILE"
echo "👉 N'oublie pas d'ajouter ce fichier à la section 'resources:' de ta Kustomization si ce n'est pas déjà fait."
