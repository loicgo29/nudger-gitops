Les warnings Longhorn venaient du check de l’agent longhorn-manager sur ton nœud :
	•	Missing packages: [nfs-common] → Longhorn utilise NFS pour certaines features (backup/restore, share). Si le package nfs-common n’est pas installé, il bloque le statut.
	•	multipathd is running → le démon multipathd tourne par défaut sur Ubuntu/Hetzner. Il gère le multipathing SAN, mais ça rentre en conflit avec la façon dont Longhorn gère les disques. Ça peut provoquer des volumes défaillants.
	•	Kernel modules [dm_crypt] are not loaded → Longhorn attend certains modules kernel (dm_crypt, device-mapper) pour chiffrer ou manipuler les volumes. S’ils ne sont pas présents, il met un warning.

👉 Bref, ce n’était pas un bug applicatif, mais une santé du nœud pas conforme pour Longhorn.
Tu as bien fait de :
	•	installer nfs-common
	•	désactiver multipathd
	•	charger dm_crypt + le déclarer dans /etc/modules-load.d/


Parfait 👍
Donc en résumé, tu avais trois warnings Longhorn côté Node Condition :
	1.	Packages manquants → nfs-common absent
✅ corrigé en installant nfs-common + dépendances.
	2.	multipathd actif
⚠️ Longhorn n’aime pas.
✅ tu l’as stoppé + désactivé (systemctl disable --now multipathd multipath-tools).
	3.	Module kernel non chargé → dm_crypt
✅ à charger avec :



modprobe dm_crypt
echo dm_crypt | sudo tee /etc/modules-load.d/dm_crypt.conf





# Pré-requis Longhorn après installation / reboot VM

## Vérifs rapides
```bash
# 1. Vérifier l’état Longhorn
kubectl -n longhorn-system get nodes.longhorn.io master1 -o yaml | yq '.status.conditions'

# 2. Vérifier les modules
lsmod | grep dm_crypt || echo "dm_crypt absent"

# 3. Vérifier que multipathd est bien off
systemctl is-active multipathd && echo "⚠️ multipathd actif"



Correctifs à appliquer


# Installer nfs-common (si pas déjà fait)
sudo apt-get update && sudo apt-get install -y nfs-common

# Désactiver multipathd
sudo systemctl disable --now multipathd multipath-tools

# Charger dm_crypt
sudo modprobe dm_crypt
echo dm_crypt | sudo tee /etc/modules-load.d/dm_crypt.conf
