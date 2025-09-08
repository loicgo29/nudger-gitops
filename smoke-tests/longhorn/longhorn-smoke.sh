#!/usr/bin/env bash
set -euo pipefail

# Résoudre le dossier du script & pointer par défaut sur les YAML à côté
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
NS="${NS:-default}"
DIR="${DIR:-${SCRIPT_DIR}}"   # <= plus besoin de passer --DIR
PVC_A="${PVC_A:-longhorn-smoke-test}"
PVC_B="${PVC_B:-longhorn-smoke-test-db}"
POD_A="${POD_A:-longhorn-smoke-pod}"
POD_B="${POD_B:-longhorn-smoke-pod-db}"

kubectl_ns(){ kubectl -n "$NS" "$@"; }
wait_pvc_bound() {
 local pvc="$1" tries=150
  # 150 * 2s = 300s
  for i in $(seq 1 $tries); do
    phase="$(kubectl_ns get pvc "$pvc" -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")"
    [[ "$phase" == "Bound" ]] && { echo "✅ pvc/$pvc Bound"; return 0; }
    sleep 2
  done
  echo "❌ pvc/$pvc not Bound after 300s"; kubectl_ns describe pvc "$pvc" | sed -n '1,200p'; exit 1
}

if [[ "${1:-}" == "--cleanup" ]]; then
  echo "🧹 Cleanup in ns=$NS from $DIR…"
  kubectl_ns delete -f "$DIR" --ignore-not-found=true
  exit 0
fi

echo "🚀 Applying $DIR …"
kubectl_ns apply -f "$DIR"
echo "🕒 Wait Pods to be Scheduled…"
kubectl_ns wait pod/"$POD_A" --for=condition=PodScheduled --timeout=300s
kubectl_ns wait pod/"$POD_B" --for=condition=PodScheduled --timeout=300s

echo "🕒 Waiting PVCs Bound (WFFC)…"
wait_pvc_bound "$PVC_A"
wait_pvc_bound "$PVC_B"
kubectl_ns get pvc "$PVC_A" "$PVC_B"

echo "🕒 Waiting pods Running…"
kubectl_ns wait pod/"$POD_A" --for=condition=Ready --timeout=300s
kubectl_ns wait pod/"$POD_B" --for=condition=Ready --timeout=300s
kubectl_ns get pod "$POD_A" "$POD_B" -o wide

echo "📝 I/O test + FS type"
kubectl_ns exec "$POD_A" -- sh -c 'dd if=/dev/zero of=/data/test.bin bs=1M count=50 status=none && sync && sha256sum /data/test.bin | tee /data/sha && df -T /data | tail -1'
kubectl_ns exec "$POD_B" -- sh -c 'dd if=/dev/zero of=/data/test.bin bs=1M count=50 status=none && sync && sha256sum /data/test.bin | tee /data/sha && df -T /data | tail -1'

echo "📦 PVC→PV mapping:"
kubectl get pv | awk 'NR==1 || /longhorn-smoke-test(-db)?/ {print}'

echo "✅ Done. Use '--cleanup' to remove resources."
