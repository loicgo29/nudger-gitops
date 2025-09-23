# 📝 RAF — Recréation VM & Workflows GitHub Actions

## 1. 🎯 Objectif
- Permettre aux workflows GitHub Actions (CI, smoke tests, etc.) d’accéder au cluster Kubernetes.  
- S’appuyer sur un **ServiceAccount dédié (`ci-runner`)** avec droits adaptés.  
- Générer un kubeconfig minimal → injecté dans GitHub comme secret `KUBECONFIG_B64`.  

---

## 2. 🛠 Étapes techniques

### 2.1. Créer la VM + cluster
- Provisionner la VM (Hetzner / autre).
- Déployer Kubernetes (via Ansible bootstrap).
- Vérifier accès `kubectl` local depuis ton poste :  
  ```bash
  kubectl get nodes
  ```

---

### 2.2. Installer Flux & composants GitOps
- Rejouer ton bootstrap Flux :  
  ```bash
  kubectl apply -k clusters/recette
  ```
- Vérifier :  
  ```bash
  kubectl -n flux-system get pods
  ```

---

### 2.3. Déclarer le ServiceAccount CI
Dans `clusters/recette/ci-runner-sa.yaml` :

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ci-runner
  namespace: flux-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ci-runner-flux
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin   # simplifié pour test (tu pourras réduire après)
subjects:
- kind: ServiceAccount
  name: ci-runner
  namespace: flux-system
```

Appliquer :
```bash
kubectl apply -k clusters/recette
```

---

### 2.4. Générer un kubeconfig minimal
Script (`scripts/ci/gen-ci-kubeconfig.sh`) :

```bash
#!/bin/bash
set -euo pipefail

SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CA=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
TOKEN=$(kubectl -n flux-system get secret ci-runner-token -o jsonpath='{.data.token}' | base64 -d)

cat <<EOF > kubeconfig-ci.yaml
apiVersion: v1
kind: Config
clusters:
- name: nudger
  cluster:
    certificate-authority-data: ${CA}
    server: ${SERVER}
contexts:
- name: nudger
  context:
    cluster: nudger
    namespace: ns-open4goods-recette
    user: ci-runner
current-context: nudger
users:
- name: ci-runner
  user:
    token: ${TOKEN}
EOF

base64 -w0 kubeconfig-ci.yaml > kubeconfig-ci.b64
echo "✅ Kubeconfig écrit dans kubeconfig-ci.yaml et kubeconfig-ci.b64"
```

---

### 2.5. Injecter dans GitHub
Uploader dans ton repo **loicgo29/nudger-gitops** :  

```bash
gh secret set KUBECONFIG_B64 < kubeconfig-ci.b64
```

Vérifier dans GitHub → *Settings > Secrets and variables > Actions*.  

---

### 2.6. Workflows
- Les workflows `.github/workflows/*.yml` utilisent le secret :  

Exemple **Smoke MySQL** :

```yaml
env:
  KUBECONFIG: ${{ github.workspace }}/kubeconfig
steps:
  - name: Restore kubeconfig
    run: |
      echo "$KUBECONFIG_B64" | base64 -d > "$KUBECONFIG"
      echo "✅ Kubeconfig restauré dans $KUBECONFIG"
    env:
      KUBECONFIG_B64: ${{ secrets.KUBECONFIG_B64 }}
```

---

## 3. ✅ Vérifications finales
1. Lancer workflow **Test Runner** :  
   ```yaml
   jobs:
     test:
       runs-on: ubuntu-latest
       steps:
         - run: kubectl get ns
   ```
   → doit afficher les namespaces du cluster.

2. Lancer workflow **Smoke MySQL** → succès attendu.

3. Lancer workflow **GitOps CI** → valide les manifests + dry-run.

---

## 4. 📌 Rappels
- **Ne jamais committer `kubeconfig-ci.yaml`** → seulement stocker le `.b64` dans GitHub Secrets.
- **RBAC** : actuellement `cluster-admin` (large). À restreindre si nécessaire.
- Toujours vérifier que `ci-runner-token` existe après réinstall.

