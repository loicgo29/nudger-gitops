#!/usr/bin/env bash
set -euo pipefail

NODE="master1"

echo "📊 Etat des disques Longhorn sur le node $NODE"
echo "-------------------------------------------------------------------------------------------"
printf "%-35s %-8s %-12s %-12s %-12s\n" "DiskPath" "Ready" "Schedulable" "Available(GB)" "Max(GB)"
echo "-------------------------------------------------------------------------------------------"

kubectl -n longhorn-system get nodes.longhorn.io "$NODE" -o yaml \
  | yq -r '
      .status.diskStatus[]
      | select(.diskPath != null and .diskPath != "")
      | [
          .diskPath,
          (.conditions[] | select(.type=="Ready") | .status),
          (.conditions[] | select(.type=="Schedulable") | .status),
          (.storageAvailable // 0),
          (.storageMaximum   // 0)
        ]
      | @tsv' \
  | while IFS=$'\t' read -r path ready sched avail max; do
        avail_gb=$((avail / 1024 / 1024 / 1024))
        max_gb=$((max / 1024 / 1024 / 1024))
        printf "%-35s %-8s %-12s %-12s %-12s\n" "$path" "$ready" "$sched" "$avail_gb" "$max_gb"
    done
