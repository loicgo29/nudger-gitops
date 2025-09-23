#!/usr/bin/env bash
set -euo pipefail

NS="ns-open4goods-recette"
RD_NAME="nudger-gitops-recette-runner"
EXPECTED_LABELS=("self-hosted" "nudger-gitops")

echo "🔍 Sanity check ARC (namespace=$NS, RunnerDeployment=$RD_NAME)"
echo "------------------------------------------------------------"
echo ""

# --- 1. Vérifier RunnerDeployment
if ! kubectl -n "$NS" get runnerdeployment "$RD_NAME" &>/dev/null; then
  echo "❌ RunnerDeployment '$RD_NAME' introuvable dans $NS"
  exit 1
fi
echo "✅ RunnerDeployment '$RD_NAME' trouvé"

RD_LABELS=$(kubectl -n "$NS" get runnerdeployment "$RD_NAME" -o jsonpath='{.spec.template.spec.labels[*]}')
echo "   Labels déclarés : [$RD_LABELS]"
for lbl in "${EXPECTED_LABELS[@]}"; do
  if echo "$RD_LABELS" | grep -qw "$lbl"; then
    echo "   ✅ Label '$lbl' présent"
  else
    echo "   ❌ Label '$lbl' manquant"
    exit 1
  fi
done

EPHEMERAL=$(kubectl -n "$NS" get runnerdeployment "$RD_NAME" -o jsonpath='{.spec.template.spec.ephemeral}')
if [[ "$EPHEMERAL" == "false" ]]; then
  echo "   ✅ Mode ephemeral=false (persistant)"
else
  echo "   ❌ Mauvaise config ephemeral=$EPHEMERAL"
  exit 1
fi

# --- 2. Vérifier Runners générés
echo ""
echo "🔍 Vérification des Runners générés..."
RUNNERS=$(kubectl -n "$NS" get runners -l runner-deployment-name="$RD_NAME" -o json | \
  jq -r '.items[] | "\(.metadata.name)\t\(.spec.labels | join(","))\t\(.spec.ephemeral)\t\(.status.phase)"')
if [ -z "$RUNNERS" ]; then
  echo "❌ Aucun Runner généré pour $RD_NAME"
  exit 1
fi

echo "$RUNNERS" | while read -r name labels ephemeral phase; do
  echo "   Runner $name → labels=[$labels], ephemeral=$ephemeral, phase=$phase"

  for lbl in "${EXPECTED_LABELS[@]}"; do
    if echo "$labels" | grep -qw "$lbl"; then
      echo "      ✅ $lbl présent"
    else
      echo "      ❌ $lbl manquant"
      exit 1
    fi
  done

  if [[ "$ephemeral" == "false" ]]; then
    echo "      ✅ ephemeral=false"
  else
    echo "      ❌ Mauvais mode ephemeral=$ephemeral"
    exit 1
  fi
done

# --- 3. Vérifier Pods associés
echo ""
echo "🔍 Vérification des Pods..."
kubectl -n "$NS" get pods -l runner-deployment-name="$RD_NAME" -o wide

# --- 4. Vérifier statut GitHub côté ARC
echo ""
echo "🔍 Vérification côté GitHub (STATUS=Running attendu)..."
kubectl -n "$NS" get runners -l runner-deployment-name="$RD_NAME" -o wide

if kubectl -n "$NS" get runners -l runner-deployment-name="$RD_NAME" -o jsonpath='{.items[*].status.phase}' | grep -qw "Running"; then
  echo "✅ Au moins un runner est Running côté GitHub"
else
  echo "❌ Aucun runner Running côté GitHub"
  exit 1
fi

echo ""
echo "🎉 Sanity check ARC terminé : tout est OK ✅"
