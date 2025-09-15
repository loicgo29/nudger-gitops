#!/usr/bin/env bash
set -euo pipefail

OUT="/tmp/flux-status.json"
GRAPH="flux-graph.md"

echo ">> Collecte des objets Flux…"
> "$OUT"
kubectl get gitrepositories.source.toolkit.fluxcd.io -A -o yaml | yq -o=json >>"$OUT"
kubectl get helmrepositories.source.toolkit.fluxcd.io -A -o yaml | yq -o=json >>"$OUT"
kubectl get helmcharts.source.toolkit.fluxcd.io -A -o yaml | yq -o=json >>"$OUT"
kubectl get helmreleases.helm.toolkit.fluxcd.io -A -o yaml | yq -o=json >>"$OUT"
kubectl get kustomizations.kustomize.toolkit.fluxcd.io -A -o yaml | yq -o=json >>"$OUT"

# helper pour afficher ✅ / ❌
status() {
  jq -r --arg kind "$1" --arg name "$2" '
    .items[]
    | select(.kind==$kind and .metadata.name==$name)
    | .status.conditions[]? | select(.type=="Ready")
    | if .status=="True" then "✅" else "❌" end
  ' "$OUT" 2>/dev/null || echo "❌"
}

echo ">> Génération du graphe Mermaid…"
cat > "$GRAPH" <<EOF
\`\`\`mermaid
graph TD

  %% --- SOURCES ---
  subgraph Flux-System
    GitRepository_gitops["📦 GitRepository gitops $(status GitRepository gitops)"]
    HelmRepository_grafana["📦 HelmRepository grafana $(status HelmRepository grafana)"]
    HelmRepository_prometheus["📦 HelmRepository prometheus-community $(status HelmRepository prometheus-community)"]
    HelmRepository_victoria["📦 HelmRepository victoria-metrics $(status HelmRepository victoria-metrics)"]
  end

  %% --- OBSERVABILITY ---
  subgraph Observability
    Kustomization_observability["⚙️ Kustomization observability $(status Kustomization observability)"]
    HelmChart_observability_grafana["📑 HelmChart grafana"]
    HelmRelease_grafana["🚀 HelmRelease grafana $(status HelmRelease grafana)"]
    HelmChart_observability_kps["📑 HelmChart kube-prometheus-stack"]
    HelmRelease_kube_prometheus_stack["🚀 HelmRelease kube-prometheus-stack $(status HelmRelease kube-prometheus-stack)"]
  end

  %% --- LOGGING ---
  subgraph Logging
    HelmChart_logging_loki["📑 HelmChart loki"]
    HelmRelease_loki["🚀 HelmRelease loki $(status HelmRelease loki)"]
    HelmChart_logging_victorialogs["📑 HelmChart victorialogs"]
    HelmRelease_victorialogs["🚀 HelmRelease victorialogs $(status HelmRelease victorialogs)"]
    HelmChart_logging_victoriametrics["📑 HelmChart victoriametrics"]
    HelmRelease_victoriametrics["🚀 HelmRelease victoriametrics $(status HelmRelease victoriametrics)"]
  end

  %% --- APPS ---
  subgraph Apps
    Kustomization_whoami["⚙️ Kustomization whoami $(status Kustomization whoami)"]
  end

  %% --- EDGES ---
  GitRepository_gitops --> Kustomization_observability
  GitRepository_gitops --> Kustomization_whoami

  HelmRepository_grafana --> HelmChart_observability_grafana --> HelmRelease_grafana
  HelmRepository_prometheus --> HelmChart_observability_kps --> HelmRelease_kube_prometheus_stack
  HelmRepository_grafana --> HelmChart_logging_loki --> HelmRelease_loki
  HelmRepository_victoria --> HelmChart_logging_victorialogs --> HelmRelease_victorialogs
  HelmRepository_victoria --> HelmChart_logging_victoriametrics --> HelmRelease_victoriametrics

  Kustomization_observability --> HelmRelease_grafana
  Kustomization_observability --> HelmRelease_kube_prometheus_stack
\`\`\`
EOF

echo "✅ Graphe généré dans $GRAPH"
