#!/usr/bin/env bash
set -euo pipefail

echo "=== Debug ARC Webhooks ==="

# 1. Vérif du service webhook
echo "[1] Service webhook dans arc-system"
kubectl -n arc-system get svc actions-runner-controller-webhook || echo "❌ Service manquant"

# 2. Vérif des MutatingWebhookConfigurations
echo "[2] MutatingWebhookConfigurations"
kubectl get mutatingwebhookconfigurations | grep actions-runner-controller || echo "❌ Aucun mutating webhook trouvé"

# 3. Vérif des ValidatingWebhookConfigurations
echo "[3] ValidatingWebhookConfigurations"
kubectl get validatingwebhookconfigurations | grep actions-runner-controller || echo "❌ Aucun validating webhook trouvé"

# 4. Dump des infos webhook (si existants)
for w in $(kubectl get mutatingwebhookconfigurations,validatingwebhookconfigurations \
  -o name | grep actions-runner-controller || true); do
  echo "--- $w ---"
  kubectl get "$w" -o yaml | grep "service:" -A5
done

# 5. Vérif des pods ARC
echo "[4] Pods ARC"
kubectl -n arc-system get pods -l app.kubernetes.io/name=actions-runner-controller

# 6. Logs du manager (les 50 dernières lignes)
echo "[5] Logs du manager"
kubectl -n arc-system logs deploy/actions-runner-controller -c manager --tail=50 || echo "⚠️ Impossible de récupérer les logs"

echo "=== Fin debug webhooks ==="
