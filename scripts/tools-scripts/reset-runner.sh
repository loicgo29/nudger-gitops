NS=ns-open4goods-recette
TARGETS=("debug-runner" "test-runner" "nudger-ci-runner-9dhbv-r6ctw")

for r in "${TARGETS[@]}"; do
  echo "---- $r ----"

  # 1) Runner CR: drop finalizers (si existe)
  if kubectl get runner "$r" -n "$NS" >/dev/null 2>&1; then
    echo "Patch finalizers (Runner) ..."
    kubectl patch runner "$r" -n "$NS" --type=merge -p '{"metadata":{"finalizers":null}}' || true
    echo "Delete (Runner) ..."
    kubectl delete runner "$r" -n "$NS" --force --grace-period=0 || true
  else
    echo "Runner CR introuvable."
  fi

  # 2) Pod: drop finalizers (si existe)
  if kubectl get pod "$r" -n "$NS" >/dev/null 2>&1; then
    echo "Patch finalizers (Pod) ..."
    kubectl patch pod "$r" -n "$NS" --type=merge -p '{"metadata":{"finalizers":null}}' || true
    echo "Delete (Pod) ..."
    kubectl delete pod "$r" -n "$NS" --force --grace-period=0 || true
  else
    echo "Pod introuvable."
  fi
done

echo "---- État restant ----"
kubectl get runners -n "$NS" || true
kubectl get pods -n "$NS" | grep -E 'debug-runner|test-runner|nudger-ci-runner' || true
