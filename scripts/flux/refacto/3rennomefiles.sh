#!/usr/bin/env bash
set -euo pipefail

echo "📦 Refactor HelmRelease / HelmRepository filenames…"

# --- Observability ---
mv infra/observability/base/loki-helmrelease.yaml                  infra/observability/base/helmrelease-loki.yaml
mv infra/observability/base/promtail-helmrelease.yaml              infra/observability/base/helmrelease-promtail.yaml
mv infra/observability/base/helmrepository-grafana.yaml            infra/observability/base/helmrepository-grafana.yaml # already ok
mv infra/observability/base/helmrepository.yaml                    infra/observability/base/helmrepository-prometheus-community.yaml
mv infra/observability/overlays/lab/grafana-helmrelease.yaml       infra/observability/overlays/lab/helmrelease-grafana.yaml
mv infra/observability/overlays/lab/helmrelease.yaml               infra/observability/overlays/lab/helmrelease-kube-prometheus-stack.yaml

# --- Longhorn ---
mv infra/longhorn/base/helmrepository.yaml                         infra/longhorn/base/helmrepository-longhorn.yaml
mv infra/longhorn/overlays/lab/helmrelease.yaml                    infra/longhorn/overlays/lab/helmrelease-longhorn.yaml

# --- Cert-Manager ---
mv infra/cert-manager/base/helmrepository.yaml                     infra/cert-manager/base/helmrepository-cert-manager.yaml
mv infra/cert-manager/overlays/lab/helmrelease.yaml                infra/cert-manager/overlays/lab/helmrelease-cert-manager.yaml

# --- Ingress ---
mv flux-system/sources/ingress-nginx-helmrepository.yaml           flux-system/sources/helmrepository-ingress-nginx.yaml

# --- Kyverno (déjà bien nommés) ---
# clusters/lab/kyverno.hr.yaml
# clusters/lab/kyverno.repo.yaml

echo "✅ Done. You may now patch your kustomization.yaml files accordingly."
