#!/usr/bin/env bash
set -euo pipefail

echo "🛠️ Mise à jour des kustomization.yaml avec les nouveaux noms de fichiers…"

# table des renommages : ancien -> nouveau
declare -A rename_map=(
  ["helmrelease.yaml"]="helmrelease-kube-prometheus-stack.yaml"
  ["grafana-helmrelease.yaml"]="helmrelease-grafana.yaml"
  ["promtail-helmrelease.yaml"]="helmrelease-promtail.yaml"
  ["loki-helmrelease.yaml"]="helmrelease-loki.yaml"
  ["helmrepository.yaml"]="helmrepository-prometheus-community.yaml"
  ["helmrepository-grafana.yaml"]="helmrepository-grafana.yaml"
  ["helmrepository-longhorn.yaml"]="helmrepository-longhorn.yaml"
  ["helmrepository-cert-manager.yaml"]="helmrepository-cert-manager.yaml"
  ["helmrelease-cert-manager.yaml"]="helmrelease-cert-manager.yaml"
  ["helmrelease-longhorn.yaml"]="helmrelease-longhorn.yaml"
  ["helmrepository-ingress-nginx.yaml"]="helmrepository-ingress-nginx.yaml"
)

# fichiers kustomization.yaml visés
mapfile -t files < <(find . -type f -name "kustomization.yaml")

for file in "${files[@]}"; do
  original="$file"
  modified=false

  for old in "${!rename_map[@]}"; do
    new="${rename_map[$old]}"
    if grep -q "$old" "$original"; then
      echo "📄 $original → $old ⟶ $new"
      sed -i "s|$old|$new|g" "$original"
      modified=true
    fi
  done

  if [ "$modified" = true ]; then
    echo "✅ Modifié : $original"
  fi
done

echo "🏁 Tous les kustomizations ont été patchés (si besoin)."
