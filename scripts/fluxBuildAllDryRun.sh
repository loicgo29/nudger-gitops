#!/usr/bin/env bash
set -euo pipefail

# Racine du repo local
REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel)}"

echo "🔧 Vérification (build dry-run) de tous les Kustomizations déclarés dans le cluster"
echo "Repo local racine : $REPO_ROOT"
echo

kubectl get kustomizations --all-namespaces \
  -o jsonpath='{range .items[*]}{.metadata.namespace}{";"}{.metadata.name}{";"}{.spec.path}{"\n"}{end}' \
  | while IFS=";" read -r ns name path; do
      echo "---------------------------"
      echo "Namespace: $ns | Kustomization: $name"
      local_path="$REPO_ROOT/${path#./}"

      if [[ ! -d "$local_path" ]]; then
        echo "❌ Chemin introuvable localement : $local_path"
        continue
      fi

      if [[ ! -f "$local_path/kustomization.yaml" && ! -f "$local_path/Kustomization" ]]; then
        echo "❌ Aucun fichier kustomization.yaml dans $local_path"
        continue
      fi

      echo "🛠 kustomize build $local_path"
      if kustomize build "$local_path" >/dev/null; then
        echo "✅ Build réussi pour $name ($local_path)"
      else
        echo "❌ Build échoué pour $name ($local_path)"
      fi

      echo
    done
