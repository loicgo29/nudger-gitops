#!/usr/bin/env bash
set -euo pipefail

echo "=============================="
echo "  ARC (Actions Runner Controller) Sanity Check"
echo "=============================="

# 1. Vérif du controller
echo -e "\n[1] Controller ARC (namespace=actions-runner-system)"
kubectl -n actions-runner-system get deploy,po,svc || true

# 2. Vérif des secrets
echo -e "\n[2] Secrets"
for ns in actions-runner-system ns-open4goods-recette ns-open4goods-integration; do
  echo "  - Namespace: $ns"
  kubectl -n "$ns" get secrets | grep actions-runner || echo "    ❌ Aucun secret trouvé"
done

# 3. Vérif des CRD
echo -e "\n[3] CRDs"
kubectl get crd | grep runner || echo "❌ Pas de CRD runner trouvé"

# 4. Vérif des RunnerDeployments
echo -e "\n[4] RunnerDeployments"
kubectl get runnerdeployments -A || true

# 5. Vérif des Pods runners
echo -e "\n[5] Pods (recette & integration)"
for ns in ns-open4goods-recette ns-open4goods-integration; do
  echo "  - Namespace: $ns"
  kubectl -n "$ns" get pods | grep runner || echo "    ❌ Aucun pod runner trouvé"
done

# 6. Vérif logs récents d’un pod runner
echo -e "\n[6] Derniers logs d’un pod runner (recette)"
runner_pod=$(kubectl -n ns-open4goods-recette get pods -o name | grep runner | head -n1 || true)
if [[ -n "$runner_pod" ]]; then
  kubectl -n ns-open4goods-recette logs "$runner_pod" -c runner --tail=20 || true
else
  echo "❌ Aucun pod runner trouvé en recette"
fi

echo -e "\n[7] Vérifie aussi côté GitHub → Repo Settings > Actions > Runners"
echo "    ✅ Un runner doit apparaître 'Online' pour chaque namespace (recette, integration)."

echo -e "\n=============================="
echo "  Fin du sanity check ARC"
echo "=============================="
