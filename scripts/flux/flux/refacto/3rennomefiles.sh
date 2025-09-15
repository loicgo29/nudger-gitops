#!/usr/bin/env bash
set -euo pipefail

echo "📦 Refactor HelmRelease / HelmRepository filenames…"

# Petite fonction utilitaire
mv_if_exists() {
  local src="$1"
  local dest="$2"
  if [[ -f "$src" ]]; then
    echo "🔁 $src ⟶ $dest"
    mv "$src" "$dest"
  else
    echo "⚠️  Fichier manquant: $src"
  fi
}

# --- Observability ---
mv_if_exists infra/observability/base/loki-helmrelease.yaml                  infra/observability/base/helmrelease-loki.yaml
mv_if_exists infra/observability/base/promtail-helmrelease.yaml              infra/observability/base/helmrelease-promtail.yaml
mv_if_exists infra/observability/base/helmrepository.yaml                    infra/observability/base/helmrepository-prometheus-community.yaml
mv_if_exists infra/observability/overlays/lab/grafana-helmrelease.yaml       infra/observability/overlays/lab/helmrelease-grafana.yaml
mv_if_exists infra/observability/overlays/lab/helmrelease.yaml               infra/observability/overlays/lab/helmrelease-kube-prometheus-stack.yaml
# (déjà correct, pas de rename requis)
# infra/observability/base/helmrepository-grafana.yaml

# --- Longhorn ---
mv_if_exists infra/longhorn/base/helmrepository.yaml                         infra/longhorn/base/helmrepository-longhorn.yaml
mv_if_exists infra/longhorn/overlays/lab/helmrelease.yaml                    infra/longhorn/overlays/lab/helmrelease-longhorn.yaml

# --- Cert-Manager ---
mv_if_exists infra/cert-manager/base/helmrepository.yaml                     infra/cert-manager/base/helmrepository-cert-manager.yaml
mv_if_exists infra/cert-manager/overlays/lab/helmrelease.yaml                infra/cert-manager/overlays/lab/helmrelease-cert-manager.yaml

# --- Ingress ---
mv_if_exists flux-system/sources/ingress-nginx-helmrepository.yaml           flux-system/sources/helmrepository-ingress-nginx.yaml

echo "✅ Fini. Passe maintenant au patch des kustomizations."
