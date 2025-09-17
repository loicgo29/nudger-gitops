#!/usr/bin/env bash
set -euo pipefail
APPLY="${1:-}"
if [[ "$APPLY" == "--help" ]]; then
  echo "Usage: $0 [--apply]   # default is dry-run"; exit 0
fi
mapfile -t PVs < <(kubectl get pv -o jsonpath='{range .items[?(@.status.phase=="Released")]}{.metadata.name}{"\n"}{end}')
if [[ ${#PVs[@]} -eq 0 ]]; then echo "✅ No Released PVs."; exit 0; fi
printf "Found Released PVs:\n"; printf " - %s\n" "${PVs[@]}"
[[ "$APPLY" == "--apply" ]] && kubectl delete pv "${PVs[@]}" || echo "ℹ️ Dry-run. Add --apply to delete."
