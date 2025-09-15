#!/usr/bin/env bash
set -euo pipefail

# Où se trouve la racine de ton clone du repo Git que Flux utilise
REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel)}"

echo "🔍 Vérification des chemins .spec.path des Kustomizations"
echo "Repo local racine : $REPO_ROOT"
echo

# Pour chaque namespace
kubectl get kustomizations --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{";"}{.metadata.name}{";"}{.spec.path}{"\n"}{end}' \
  | while IFS=";" read -r ns name path; do
      # Normaliser le chemin
      if [[ -z "$path" ]]; then
        status="EMPTY_PATH"
        local_path="$REPO_ROOT"
      else
        local_path="$REPO_ROOT/$path"
      fi

      # Vérifier si le répertoire ou fichier existe
      if [[ -d "$local_path" ]] || [[ -f "$local_path"/kustomization.yaml ]] || [[ -f "$local_path"/Kustomization ]]; then
        result="OK"
      else
        result="MISSING"
      fi

      printf "%-20s %-30s Path: %-40s → %s\n" "Namespace:$ns" "Name:$name" "Spec.path:'$path'" "$result"
    done
