#!/usr/bin/env bash
set -euo pipefail

echo "== Vérification des prérequis Longhorn =="

# Installer nfs-common si absent
if ! dpkg -s nfs-common >/dev/null 2>&1; then
  echo "→ Installation de nfs-common"
  sudo apt-get update -y
  sudo apt-get install -y nfs-common
else
  echo "✓ nfs-common déjà présent"
fi

# Désactiver multipathd
echo "→ Désactivation multipathd"
sudo systemctl disable --now multipathd multipath-tools || true

# Charger dm_crypt
if ! lsmod | grep -q dm_crypt; then
  echo "→ Chargement dm_crypt"
  sudo modprobe dm_crypt
fi

echo dm_crypt | sudo tee /etc/modules-load.d/dm_crypt.conf >/dev/null

echo "== Terminé, état du node :"
kubectl -n longhorn-system get nodes.longhorn.io -o wide
