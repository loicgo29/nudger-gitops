#!/usr/bin/env bash
set -euo pipefail

echo "🧪 Vérifications post-refacto HelmRelease..."

echo "1. 🔍 Doublons de 'name:' dans les releases"
grep -r '^  name:' infra/observability/releases/ | sort | uniq -d || echo "✅ Aucun doublon"

echo "2. 🧼 Fichiers helmrelease-*.yaml encore présents ?"
find . -name 'helmrelease-*.yaml' || echo "✅ Aucun fichier helmrelease-*.yaml trouvé"

echo "3. 🔧 kustomize build global"
find . -name kustomization.yaml -execdir kustomize build . \; > /dev/null && echo "✅ Tous les kustomization.yaml sont valides"

echo "4. 🚨 kustomization.yaml sans resources:"
grep -rL 'resources:' . --include='kustomization.yaml' || echo "✅ Tous les kustomization.yaml ont des resources"

echo "5. 🧱 kustomization.yaml avec path en double ?"
grep -rE '^\s*-\s+\.\./.+' --include='kustomization.yaml' | sort | uniq -c | sort -rn | grep -v '^ *1 ' || echo "✅ Aucun doublon de path"

echo "6. 🧪 Compilation de clusters/lab"
kustomize build clusters/lab > /dev/null && echo "✅ clusters/lab build OK"

echo "7. 🧪 flux build (optionnel, local seulement)"
flux build kustomization lab-root --kubeconfig ~/.kube/config || echo "⚠️ flux build KO (si non applicable, ignorer)"

echo "🎉 Toutes les vérifications sont terminées."
