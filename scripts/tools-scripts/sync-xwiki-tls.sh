#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# Script: sync-xwiki-tls.sh
# Objectif : synchroniser le secret TLS `xwiki-tls` entre ns-open4goods-recette
#             et ns-open4goods-integration (copie "recette" → "integration").
# Usage:
#   ./scripts/autom/sync-xwiki-tls.sh
# ------------------------------------------------------------------------------

SRC_NS="ns-open4goods-recette"
DST_NS="ns-open4goods-integration"
SECRET_NAME="xwiki-tls"

echo "🔎 Vérification du certificat dans $SRC_NS..."
if ! kubectl get secret -n "$SRC_NS" "$SECRET_NAME" >/dev/null 2>&1; then
  echo "❌ Secret $SECRET_NAME introuvable dans $SRC_NS"
  exit 1
fi

echo "📥 Export du secret depuis $SRC_NS..."
kubectl get secret -n "$SRC_NS" "$SECRET_NAME" -o yaml \
  | sed "s/namespace: $SRC_NS/namespace: $DST_NS/" \
  | kubectl apply -n "$DST_NS" -f -

echo "✅ Secret $SECRET_NAME copié dans $DST_NS"
