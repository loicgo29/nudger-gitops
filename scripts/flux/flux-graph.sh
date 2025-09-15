#!/usr/bin/env bash
set -euo pipefail

OUT="sources.json"
> "$OUT"

echo ">> Dump en JSON tous les objets Flux connus…"

kubectl get gitrepositories.source.toolkit.fluxcd.io -A -o yaml \
  | yq -o=json >>"$OUT"

kubectl get helmrepositories.source.toolkit.fluxcd.io -A -o yaml \
  | yq -o=json >>"$OUT"

kubectl get helmcharts.source.toolkit.fluxcd.io -A -o yaml \
  | yq -o=json >>"$OUT"

kubectl get helmreleases.helm.toolkit.fluxcd.io -A -o yaml \
  | yq -o=json >>"$OUT"

kubectl get kustomizations.kustomize.toolkit.fluxcd.io -A -o yaml \
  | yq -o=json >>"$OUT"

echo ">> Données brutes collectées dans $OUT"
echo ">> Aperçu (jq . | head -50) :"
jq . "$OUT" | head -50
