#!/usr/bin/env bash
set -euo pipefail

echo "🔍 Vérifications post-refacto HelmRelease..."

err=0

echo "1. 🔎 Doublons de name dans les releases"
if grep -r '^  name:' infra/observability/releases/ | sort | uniq -d | grep .; then
  echo "❌ Doublons détectés"
  err=1
else
  echo "✅ Aucun doublon"
fi

echo "2. 🧼 Présence de fichiers helmrelease-*.yaml"
if find . -name 'helmrelease-*.yaml' | grep .; then
  echo "❌ Des helmrelease-*.yaml subsistent"
  err=1
else
  echo "✅ Aucun helmrelease-*.yaml trouvé"
fi

echo "3. 🧪 Build de tous les kustomization.yaml"
if ! find . -name kustomization.yaml -execdir kustomize build . \; > /dev/null; then
  echo "❌ Erreur de build kustomize"
  err=1
else
  echo "✅ Tous les builds passent"
fi

echo "4. 🚨 kustomization.yaml sans resources:"
if grep -rL 'resources:' . --include='kustomization.yaml' | grep .; then
  echo "❌ Certains kustomization.yaml sont vides"
  err=1
else
  echo "✅ Tous ont des resources"
fi

echo "5. 🧱 Chemins en doublon dans les kustomization.yaml"
if grep -rE '^\s*-\s+\.\./.+' --include='kustomization.yaml' | sort | uniq -c | sort -rn | grep -v '^ *1 ' | grep .; then
  echo "❌ Des chemins identiques sont utilisés plusieurs fois"
  err=1
else
  echo "✅ Aucun doublon de path"
fi

exit $err
