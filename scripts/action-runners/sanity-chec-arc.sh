#!/usr/bin/env bash
set -euo pipefail

echo "=============================="
echo "  ARC (Actions Runner Controller) Sanity Check"
echo "=============================="

# [1] Controller ARC (namespace=actions-runner-system)
echo
echo "[1] Controller ARC (namespace=actions-runner-system)"
kubectl -n actions-runner-system get deploy,po,svc

# [2] Secrets par namespace
for ns in actions-runner-system ns-open4goods-recette ns-open4goods-integration; do
  echo
  echo "[2] Secrets - Namespace: $ns"
  kubectl -n "$ns" get sealedsecrets,secrets 2>/dev/null || true
done

# [3] CRDs ARC
echo
echo "[3] CRDs"
kubectl get crd | grep runner || true

# [4] RunnerDeployments
echo
echo "[4] RunnerDeployments"
kubectl get runnerdeployments -A

# [5] Pods runners (recette + integration)
for ns in ns-open4goods-recette ns-open4goods-integration; do
  echo
  echo "[5] Pods - Namespace: $ns"
  kubectl -n "$ns" get pods -l 'runner-deployment-name' 2>/dev/null || true
done

# [6] Derniers logs d’un pod runner (si dispo)
for ns in ns-open4goods-recette ns-open4goods-integration; do
  echo
  echo "[6] Derniers logs - Namespace: $ns"
  pod=$(kubectl -n "$ns" get pods -l 'runner-deployment-name' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [[ -n "$pod" ]]; then
    kubectl -n "$ns" logs "$pod" -c runner --tail=20 || true
  else
    echo "    ❌ Aucun pod runner trouvé dans $ns"
  fi
done

# [7] Rappel GitHub
echo
echo "[7] Vérifie aussi côté GitHub → Repo Settings > Actions > Runners"
echo "    ✅ Un runner doit apparaître 'Online' pour chaque namespace (recette, integration)."

echo
echo "=============================="
echo "  Fin du sanity check ARC"
echo "=============================="
