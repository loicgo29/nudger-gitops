#!/usr/bin/env bash
set -euo pipefail

APP="${1:-}"

if [[ -z "$APP" ]]; then
  echo "Usage: $0 <app-name>"
  echo "Ex: $0 grafana | ingress-nginx | loki | promtail"
  exit 1
fi

echo ">> Reconcile source gitops"
flux -n flux-system reconcile source git gitops || true

case "$APP" in
  grafana)
    echo ">> Reconcile Kustomization observability"
    flux -n flux-system reconcile kustomization observability --with-source || true
    echo ">> Reconcile HelmRelease grafana"
    flux -n observability reconcile helmrelease grafana --with-source || true
    ;;

  ingress-nginx)
    echo ">> Reconcile Kustomization ingress-nginx"
    flux -n flux-system reconcile kustomization ingress-nginx --with-source || true
    echo ">> Reconcile HelmRelease ingress-nginx"
    flux -n ingress-nginx reconcile helmrelease ingress-nginx --with-source || true
    ;;

  loki|promtail)
    echo ">> Reconcile Kustomization observability"
    flux -n flux-system reconcile kustomization observability --with-source || true
    echo ">> Reconcile HelmRelease ${APP}"
    flux -n logging reconcile helmrelease "${APP}" --with-source || true
    ;;

  observability)
flux -n flux-system reconcile source git gitops
flux -n flux-system resume kustomization observability
flux -n flux-system reconcile kustomization observability --with-source

  *)
    echo ">> Reconcile ALL Kustomizations (fallback)"
    flux get kustomizations -A
    echo ">> Trying HelmRelease ${APP} in observability"
    flux -n observability reconcile helmrelease "${APP}" --with-source || true
    ;;
esac
