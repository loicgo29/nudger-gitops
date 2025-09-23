#!/usr/bin/env bash
set -euo pipefail

NS="flux-system"
SECRET_NAME="flux-system"
KEY="$HOME/.ssh/id_deploy_nudger"
KEY_PUB="${KEY}.pub"
KNOWN_HOSTS="$HOME/.ssh/known_hosts"

echo "🔍 Vérification de la clé SSH..."
if [[ ! -f "$KEY" ]]; then
  echo "❌ Clé privée $KEY introuvable"
  exit 1
fi

if [[ ! -f "$KEY_PUB" ]]; then
  echo "⚡ Génération de la clé publique..."
  ssh-keygen -y -f "$KEY" > "$KEY_PUB"
fi

if [[ ! -f "$KNOWN_HOSTS" ]]; then
  echo "⚡ Ajout de github.com dans known_hosts..."
  ssh-keyscan -t rsa github.com >> "$KNOWN_HOSTS"
fi

echo "🚀 Création/MàJ du secret $SECRET_NAME dans $NS..."
kubectl -n "$NS" create secret generic "$SECRET_NAME" \
  --from-file=identity="$KEY" \
  --from-file=identity.pub="$KEY_PUB" \
  --from-file=known_hosts="$KNOWN_HOSTS" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Secret $SECRET_NAME recréé avec succès."
