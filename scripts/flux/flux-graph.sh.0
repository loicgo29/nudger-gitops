#!/usr/bin/env bash
set -euo pipefail

OUT="sources.json"
echo ">> Collecting Flux objects into $OUT…"
: >"$OUT"   # vide le fichier

# Dump en JSON tous les objets Flux connus
kubectl get gitrepositories.source.toolkit.fluxcd.io -A -o yaml | yq -o=json >>"$OUT"
kubectl get helmrepositories.source.toolkit.fluxcd.io -A -o yaml | yq -o=json >>"$OUT"
kubectl get helmcharts.source.toolkit.fluxcd.io -A -o yaml | yq -o=json >>"$OUT"
kubectl get helmreleases.helm.toolkit.fluxcd.io -A -o yaml | yq -o=json >>"$OUT"
kubectl get kustomizations.kustomize.toolkit.fluxcd.io -A -o yaml | yq -o=json >>"$OUT"

echo ">> Building Mermaid graph…"
cat <<'EOF'
```mermaid
graph TD
  subgraph Sources
    GitRepos[GitRepositories]
    HelmRepos[HelmRepositories]
  end

  subgraph Releases
    HelmCharts[HelmCharts]
    HelmReleases[HelmReleases]
    Kustomizations[Kustomizations]
  end

  GitRepos --> Kustomizations
  HelmRepos --> HelmCharts --> HelmReleases
  HelmReleases --> Kustomizations
