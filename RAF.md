git config pull.ff only

apt  install gh
---------
	•	Installe uniquement via Flux/HelmRelease.
--------
. Ingress / HTTP-01 ACME
	•	Ton ingress-nginx exposait seulement en NodePort (30080/30443). Let’s Encrypt a besoin d’accéder directement :80 / :443.
	•	À retenir :
	•	Activer hostPort dans le chart nginx ou ajouter un LoadBalancer si ton infra le permet.
	•	Sinon, prévoir une règle iptables persistante qui redirige :
	•	80 → 30080
	•	443 → 30443
	•	Vérifier :


curl -I http://<ton-ip>
curl -I http://<ton-domaine>/.well-known/acme-challenge/test
-----------
À appliquer avant de booter le cluster :
	•	🔹 Paquets système : nfs-common, multipath-tools (mais multipathd désactivé), open-iscsi, jq, curl, socat.
	•	🔹 Kernel mods : charger ce que Longhorn attend (dm_crypt si tu veux le chiffrement).
	•	🔹 Sysctl :
	•	net.ipv4.ip_forward=1
	•	fs.inotify.max_user_instances, etc. (selon kubeadm).
	•	🔹 Pare-feu :
	•	Autoriser / rediriger 80 et 443 vers ingress-nginx.
	•	Laisser passer 6443/tcp (API k8s).
	•	🔹 SSH/Users : clés déjà provisionnées (Ansible friendly).
	•	🔹 Swap : désactivé.
	•	🔹 Cgroup driver : systemd configuré pour containerd.A


	•	Vérifier les règles iptables/ufw → tu as vu que ton ufw est inactive, donc il faut ajouter une redirection persistante 80→30080 et 443→30443 o
sudo iptables -t nat -A PREROUTING -p tcp --dport 80  -j REDIRECT --to-ports 30080
sudo iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-ports 30443
