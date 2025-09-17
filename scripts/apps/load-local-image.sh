#!/bin/bash
set -euo pipefail
IMG=$1

echo "🔄 Export Docker image $IMG → /tmp/$IMG.tar"
sudo docker save $IMG -o /tmp/$IMG.tar

echo "📥 Import into containerd (namespace k8s.io)"
sudo ctr -n k8s.io images import /tmp/$IMG.tar

echo "✅ Image $IMG ready for Kubernetes pods"
