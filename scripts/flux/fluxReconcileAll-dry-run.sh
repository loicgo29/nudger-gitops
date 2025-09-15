#!/usr/bin/env bash
set -euo pipefail

# Configuration : tu peux adapter
# Si tu veux limiter à certains Kustomizations, ou tous.
KST_PATH="./"             # chemin racine où chercher les kustomizations
FLUX_NAMESPACE="${FLUX_NAMESPACE:-flux-system}"  # namespace de flux si besoin

# Fonction : build + dry-run pour une kustomization
run_one() {
  local ns="$1"
  local name="$2"
  local path="$3"

  echo
  echo "=== Kustomization: $name  (namespace: $ns) ==="
  echo "> flux build kustomization $name --path $path --dry-run"
  flux build kustomization "$name" --path "$path" --dry-run

  echo
  echo "> flux diff kustomization $name --path $path"
  flux diff kustomization "$name" --path "$path"
}

# Main : liste toutes les kustomizations et les exécute
# On utilise kubectl pour récupérer namespace + name + gestion du chemin local
kubectl get kustomizations --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{";"}{.metadata.name}{";"}{.spec.path}{"\n"}{end}' \
  | while IFS=";" read -r ns name path; do
      # Filtrer les chemins invalides ou relatifs non trouvés
      if [[ -z "$path" ]]; then
        echo "⚠️ Skip $name in $ns: .spec.path vide"
        kubectl get kustomization $name -n $ns -o yaml | grep "path:"
        continue
      fi
      if [[ ! -d "$path" && ! -f "$path"/kustomization.yaml && ! -f "$path"/Kustomization ]]; then
        echo "⚠️ Skip $name in $ns: path \"$path\" non trouvé localement"
	    echo "⚠️ Skip $name in $ns: .spec.path vide"
        kubectl get kustomization $name -n $ns -o yaml | grep "path:"

        continue
      fi

      run_one "$ns" "$name" "$path"
    done
