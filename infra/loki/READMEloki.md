helm upgrade --install loki grafana/loki-stack -f promtail-values.yaml

# Guide de Réinstallation de la VM et de la Configuration de Kubernetes, Grafana et Loki

Ce guide détaille les étapes à suivre en cas de réinstallation de la VM, de configuration de Kubernetes et du déploiement des services comme Grafana et Loki. Il inclut également des étapes de sauvegarde et de restauration pour garantir la continuité de l'environnement.

## 1) Préparer la réinstallation de la VM

Avant de réinstaller la VM, sauvegarder les fichiers de configuration et les données critiques. Voici les commandes utiles :

### Sauvegarder les fichiers de configuration
```bash
tar -czvf nudger-gitops-backup.tar.gz ~/nudger/infra/k8s_ansible/
```

### Sauvegarder les secrets et configmaps Kubernetes
```bash
kubectl get secrets -A -o yaml > kubernetes-secrets.yaml
kubectl get configmaps -A -o yaml > kubernetes-configmaps.yaml
```

## 2) Réinstaller la VM

### Réinstaller l'OS (Ubuntu recommandé) et mettre à jour
```bash
sudo apt update && sudo apt upgrade -y
```

## 3) Reconfigurer le système

### Vérifier les limites des fichiers ouverts (ulimit)
```bash
ulimit -n  # Affiche le nombre de fichiers ouverts autorisés
```

### Ajuster les limites si nécessaire
Modifie `/etc/security/limits.conf` :
```bash
sudo vim /etc/security/limits.conf
```
Ajoute les lignes suivantes :
```
* soft nofile 524288
* hard nofile 524288
```

Modifie `/etc/systemd/system.conf` :
```bash
sudo vim /etc/systemd/system.conf
```
Ajoute ou modifie cette ligne :
```
DefaultLimitNOFILE=524288
```

### Recharger les configurations
```bash
sudo systemctl daemon-reload
sudo systemctl restart systemd-logind
```

### Vérifier et ajuster les paramètres du noyau
```bash
sysctl fs.inotify.max_user_watches
```
Si nécessaire, ajuste :
```bash
sudo sysctl -w fs.inotify.max_user_watches=524288
```

Ajoute cette ligne à `/etc/sysctl.conf` pour persister :
```bash
echo "fs.inotify.max_user_watches=524288" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

## 4) Réinstaller Kubernetes (et ses composants)

### Installer Kubernetes, Docker ou containerd
```bash
sudo apt install -y kubelet kubeadm kubectl
sudo apt install -y docker.io
```

### Initialiser Kubernetes
```bash
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
```

### Configurer kubectl pour l'utilisateur courant
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### Déployer le CNI (Flannel, Calico, etc.)
```bash
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

### Joindre les nœuds au cluster
Exécute la commande donnée par `kubeadm init` sur les nœuds à joindre.

## 5) Réinstaller et déployer les services Kubernetes

### Réinstaller Helm
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### Réinstaller les charts Grafana et Loki via Helm
```bash
helm upgrade --install loki grafana/loki-stack -f loki-values.yaml
helm upgrade --install grafana grafana/grafana -f grafana-values.yaml
```

### Réappliquer les ressources Kubernetes depuis GitOps (si applicable)
```bash
flux reconcile kustomization <nom-de-ton-kustomization> --with-source
```

### Redéployer Promtail
```bash
kubectl apply -f promtail-daemonset.yaml
```

## 6) Vérifier l'intégrité du système

### Vérifier les pods
```bash
kubectl get pods -A
```

### Vérifier les logs de Promtail et Loki
```bash
kubectl logs -l app.kubernetes.io/name=promtail --tail=50
kubectl logs -l app.kubernetes.io/name=loki --tail=50
```

## 7) Sauvegarder à nouveau les secrets et configmaps

### Restaurer les secrets et configmaps si nécessaires
```bash
kubectl apply -f kubernetes-secrets.yaml
kubectl apply -f kubernetes-configmaps.yaml
```
=====================
INSUFISANT
===========

# Actions to Take in Case of VM Redeployment

In the case of redeploying your VM, please follow these steps:

## 1. System Configuration
- Increase the number of open files:  
  Update `/etc/security/limits.conf`:
  ```
  * hard nofile 524288
  * soft nofile 524288
  ```
  Reload the system with:
  ```
  sudo sysctl -p
  ```

- Set default file descriptor limits in `systemd`:
  ```
  sudo vim /etc/systemd/system.conf
  ```
  Change `DefaultLimitNOFILE` to `524288`.

- Reload systemd:
  ```
  sudo systemctl daemon-reload
  ```

## 2. Loki and Promtail
- Ensure Loki and Promtail are installed and properly configured.

### Promtail DaemonSet
If necessary, patch the DaemonSet `loki-promtail`:
```bash
kubectl -n default patch ds loki-promtail --type='merge' -p='{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "promtail",
          "image": "docker.io/grafana/promtail:2.9.3",
          "resources": {
            "requests": { "cpu": "100m", "memory": "128Mi" },
            "limits":   { "cpu": "300m", "memory": "256Mi" }
          }
        }]
      }
    }
  }
}'
```

### Rolling Update
Check the status of the DaemonSet and confirm rollout:
```bash
kubectl -n default rollout status ds/loki-promtail
```

### Verify Loki Health
Ensure Loki is healthy by running a `curl` test:
```bash
kubectl run -it --rm test --image=curlimages/curl --restart=Never --   curl -s http://loki:3100/ready
```

## 3. Reinstall Applications
- Reinstall any missing applications such as `grafana`, `promtail`, or other services.

## 4. Verify Pod Status
- Confirm the pods are in the correct state:
```bash
kubectl get po
```

- If any pod is not running or stuck, delete and recreate it:
```bash
kubectl delete po <pod-name>
```

## 5. Confirm Services
Ensure that your services, including Grafana, Loki, and Promtail, are running as expected by checking their respective pods and logs.

```bash
kubectl logs <pod-name>
```

## 6. Check Disk Usage
Check disk usage and clean up any unnecessary files:
```bash
df -h
```

After completing these steps, your VM should be redeployed successfully with Loki and Promtail operational.

