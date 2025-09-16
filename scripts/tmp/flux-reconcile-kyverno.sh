#!/usr/bin/env bash
set -euo pipefail

NS=flux-system
KS_NAME=kyverno-policies

echo "⚡ [STEP 0] Suspend reconciliation for $KS_NAME"
flux suspend kustomization $KS_NAME -n $NS || true

echo "🧹 [STEP 1] Delete Kyverno CRDs if present"
for crd in clusterpolicies.kyverno.io policies.kyverno.io policyexceptions.kyverno.io updaterequests.kyverno.io; do
  kubectl delete crd $crd --ignore-not-found
done

echo "🧹 [STEP 2] Delete Kyverno namespace (if any leftover objects)"
kubectl delete ns kyverno --ignore-not-found

echo "🧹 [STEP 3] Clean any leftover webhooks"
kubectl delete validatingwebhookconfigurations kyverno-validate --ignore-not-found
kubectl delete mutatingwebhookconfigurations kyverno-mutating-webhook-cfg --ignore-not-found

echo "⚡ [STEP 4] Resume reconciliation"
flux resume kustomization $KS_NAME -n $NS

echo "🚀 [STEP 5] Force reconcile $KS_NAME"
flux reconcile kustomization $KS_NAME -n $NS --with-source
