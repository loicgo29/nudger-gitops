#!/usr/bin/env bash
set -euo pipefail

# Inventaire + hôte
INV_FILE="${INV_FILE:-/Users/loicgourmelon/Devops/nudger/infra/k8s_ansible/inventory.ini}"
HOST="${1:-master1}"

# Sanity checks
if [[ ! -f "$INV_FILE" ]]; then
  echo "Inventory introuvable: $INV_FILE" >&2
  exit 1
fi

# Récupère ansible_host / ansible_ssh_private_key_file pour l'hôte
# (user forcé à ops-loic-1)
read -r ip key <<EOF
$(awk -v h="$HOST" '
  /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
  $1 == h {
    for (i=2;i<=NF;i++) {
      n=split($i,a,"=")
      if (n==2) {
        gsub(/^"/,"",a[2]); gsub(/"$/,"",a[2]);
        gsub(/^'\''/,"",a[2]); gsub(/'\''$/,"",a[2]);
        if (a[1]=="ansible_host") host=a[2];
        else if (a[1]=="ansible_ssh_private_key_file" || a[1]=="ansible_private_key_file") key=a[2];
      }
    }
    print host "\t" key;
    exit
  }
' "$INV_FILE")
EOF

if [[ -z "${ip:-}" ]]; then
  echo "Hôte '$HOST' introuvable dans $INV_FILE ou ansible_host manquant." >&2
  exit 1
fi

user="ops-loic-1"
key="${key:-}"

# Expand ~ au début du chemin de clé si présent (sans eval)
case "$key" in
  "~/"*) key="${HOME}${key#\~}";;
esac

ssh_args=(-o StrictHostKeyChecking=accept-new)
[[ -n "$key" ]] && ssh_args+=(-i "$key")
ssh_args+=(-t -t)

echo "→ SSH vers ${user}@${ip} ${key:+(clé: $key)}"

exec ssh "${ssh_args[@]}" "${user}@${ip}" "cd ~/nudger-gitops && exec bash -l"
