#!/usr/bin/env bash
set -euo pipefail
echo ">> kustomize build (validation locale)"
kubectl kustomize infra/namespaces >/dev/null && echo "[OK] build"
echo ">> Aperçu des namespaces (s'ils existent déjà)"
kubectl get ns -L environment 2>/dev/null | egrep 'open4goods-|observability' || true
