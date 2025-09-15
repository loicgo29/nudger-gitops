#!/usr/bin/env bash
set -euo pipefail

JSON="sources.json"
OUT="flux-graph.md"

echo ">> Building Mermaid graph…"

{
  echo '```mermaid'
  echo 'graph TD'

  # GitRepositories -> Kustomizations
  jq -r '
    .items[] 
    | select(.kind=="Kustomization") 
    | "  " + .spec.sourceRef.kind + "_" + .spec.sourceRef.name + " --> " + "Kustomization_" + .metadata.name
  ' "$JSON" | sort -u

  # HelmRepositories -> HelmCharts
  jq -r '
    .items[] 
    | select(.kind=="HelmChart") 
    | "  " + .spec.sourceRef.kind + "_" + .spec.sourceRef.name + " --> " + "HelmChart_" + .metadata.name
  ' "$JSON" | sort -u

  # HelmCharts -> HelmReleases
  jq -r '
    .items[] 
    | select(.kind=="HelmRelease") 
    | "  " + "HelmChart_" + .metadata.name + " --> " + "HelmRelease_" + .metadata.name
  ' "$JSON" | sort -u

  # HelmReleases -> Kustomizations (si applicable)
  jq -r '
    .items[] 
    | select(.kind=="Kustomization" and .spec.dependsOn!=null)
    | .spec.dependsOn[]
    | "  " + "HelmRelease_" + .name + " --> " + "Kustomization_dep_" + .name
  ' "$JSON" | sort -u

  echo '```'
} > "$OUT"

echo ">> Graph generated at $OUT"
