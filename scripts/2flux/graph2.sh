#!/usr/bin/env bash
set -euo pipefail

OUT="/tmp/flux-objects.json"
GRAPH="flux-graph.md"

echo ">> Collecte des objets Flux en JSON…"
> "$OUT"

kubectl get gitrepositories.source.toolkit.fluxcd.io -A -o yaml | yq -o=json >>"$OUT"
kubectl get helmrepositories.source.toolkit.fluxcd.io -A -o yaml | yq -o=json >>"$OUT"
kubectl get helmcharts.source.toolkit.fluxcd.io -A -o yaml | yq -o=json >>"$OUT"
kubectl get helmreleases.helm.toolkit.fluxcd.io -A -o yaml | yq -o=json >>"$OUT"
kubectl get kustomizations.kustomize.toolkit.fluxcd.io -A -o yaml | yq -o=json >>"$OUT"

echo ">> Génération du graphe Mermaid…"
{
cat <<'EOF'
```mermaid
graph TD
  %% Styles d'état
  classDef ready fill:#bbf,stroke:#333,stroke-width:2px;
  classDef notready fill:#fbb,stroke:#333,stroke-width:2px;
  classDef unknown fill:#ffb,stroke:#333,stroke-width:2px;

  subgraph flux-system [Flux System]
EOF

jq -r '
  .items[]?
  | select(.kind=="GitRepository" or .kind=="HelmRepository" or .kind=="HelmChart" or .kind=="HelmRelease" or .kind=="Kustomization")
  | "\(.kind)_\(.metadata.name)_\(.metadata.namespace):::"
    + (if (.status.conditions[]? | select(.type=="Ready") | .status) == "True" then "ready"
       elif (.status.conditions[]? | select(.type=="Ready") | .status) == "False" then "notready"
       else "unknown" end)
' "$OUT"

cat <<'EOF'
  end

  subgraph observability [Observability]
    HelmRelease_grafana_observability
    HelmRelease_kube-prometheus-stack_observability
    HelmRelease_victorialogs_logging
    HelmRelease_victoriametrics_logging
  end

  subgraph apps [Apps]
    HelmRelease_whoami_flux-system
  end

  %% Liens logiques
  GitRepository_gitops_flux-system --> Kustomization_infra-namespaces_flux-system
  GitRepository_gitops_flux-system --> Kustomization_ingress-nginx_flux-system
  GitRepository_gitops_flux-system --> Kustomization_observability_flux-system
  GitRepository_gitops_flux-system --> Kustomization_whoami_flux-system

  HelmRepository_grafana_flux-system --> HelmChart_observability-grafana_flux-system --> HelmRelease_grafana_observability
  HelmRepository_prometheus-community_flux-system --> HelmChart_observability-kube-prometheus-stack_flux-system --> HelmRelease_kube-prometheus-stack_observability
  HelmRepository_victoria-metrics_flux-system --> HelmChart_logging-victorialogs_flux-system --> HelmRelease_victorialogs_logging
  HelmRepository_victoria-metrics_flux-system --> HelmChart_logging-victoriametrics_flux-system --> HelmRelease_victoriametrics_logging
EOF

echo '```'
} > "$GRAPH"

echo ">> Graphe Mermaid écrit dans $GRAPH"
