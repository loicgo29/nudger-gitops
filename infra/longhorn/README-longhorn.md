# Runbook Longhorn — Volumes (Kubernetes)

> **Objectif :** procédures de base pour créer, étendre et restaurer un volume Longhorn.
> ⚠️ Backups (S3, RecurringJobs) ne sont **pas** couverts ici.

---

## 1. Créer un volume (via PVC)

### Exemple de PVC
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-data
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: longhorn   # ou longhorn-db
```
```bash
kubectl apply -f pvc.yaml
kubectl get pvc my-data
# STATUS doit être Bound
```

### Utilisation dans un Pod
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  containers:
  - name: busybox
    image: busybox
    command: ["sh", "-c", "sleep 3600"]
    volumeMounts:
    - mountPath: /data
      name: data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: my-data
```

---

## 2. Étendre un volume (expansion)

### Étape 1 : Modifier le PVC
```bash
kubectl patch pvc my-data -p '{ "spec": { "resources": { "requests": { "storage": "10Gi" }}}}'
```

### Étape 2 : Vérifier
```bash
kubectl get pvc my-data
# CAPACITY doit afficher 10Gi
```

### Étape 3 : Redémarrage éventuel du Pod
Certaines applis nécessitent un redémarrage pour voir la nouvelle taille.

---

## 3. Restaurer un volume

Deux cas possibles :

### a) Restaurer à partir d’un snapshot local
1. Aller dans l’UI Longhorn (port-forward : `kubectl -n longhorn-system port-forward svc/longhorn-frontend 8080:80` puis http://localhost:8080).
2. Sélectionner le volume → onglet **Snapshots**.
3. Choisir le snapshot et cliquer **Revert** (⚠️ le contenu actuel sera écrasé par le snapshot).

### b) Restaurer vers un nouveau volume (à partir d’un snapshot)
1. UI Longhorn → **Snapshots** → **Create PV/PVC from Snapshot**.
2. Cela génère un nouveau PVC utilisable par une autre app.

---

## 4. Suppression d’un volume
```bash
kubectl delete pvc my-data
# Longhorn libère le PV associé
```

⚠️ Ne pas supprimer les CRDs Longhorn si des volumes existent.

---

## Résumé
- **Créer** → PVC avec `storageClassName=longhorn` ou `longhorn-db`.
- **Étendre** → `kubectl patch pvc` + vérifier CAPACITY.
- **Restaurer** → via UI Longhorn (snapshots locaux) → Revert ou Create PVC from Snapshot.
- **Nettoyer** → `kubectl delete pvc` (Longhorn gère la suppression du PV).

