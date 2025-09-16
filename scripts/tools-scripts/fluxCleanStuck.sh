#!/usr/bin/env bash
set -euo pipefail

echo "🧹 [CLEANUP] Déblocage des ressources Flux coincées..."

# Durée max (en minutes) pour considérer qu'une ressource est coincée
MAX_AGE_MINUTES=5
MAX_AGE_SECONDS=$((MAX_AGE_MINUTES * 60))

# --- Fonction générique ---
clean_stuck_resources() {
  local kind=$1
  local group=$2

  echo "🔎 Recherche de ${kind}.${group} coincés (Progressing depuis > ${MAX_AGE_MINUTES} min)..."

  kubectl get "${kind}.${group}" -A -o json | jq -r \
    --argjson maxAge "$MAX_AGE_SECONDS" \
    --arg kind "$kind" \
    '.items[]
    | select(.status.conditions[]?.reason=="Progressing")
    | select((now - (.metadata.creationTimestamp | fromdate)) > $maxAge)
    | "\(.metadata.namespace) \(.metadata.name)"' | while read -r ns name; do

      echo "⚠️  ${kind} coincé détecté : $ns/$name"

      echo "   🔧 Suppression des finalizers..."
      kubectl patch "${kind}.${group}" "$name" -n "$ns" \
        --type merge -p '{"metadata":{"finalizers":[]}}' || true

      echo "   🔄 Relance reconciliation..."
      flux reconcile "$kind" "$name" -n "$ns" --with-source || true
  done
}

# --- Nettoyage ---
clean_stuck_resources "kustomization" "kustomize.toolkit.fluxcd.io"
clean_stuck_resources "helmrelease" "helm.toolkit.fluxcd.io"

echo "✅ Vérifie l’état final :"
kubectl get kustomizations.kustomize.toolkit.fluxcd.io -A
kubectl get helmreleases.helm.toolkit.fluxcd.io -A
