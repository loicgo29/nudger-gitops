# 🚀 Intégration GitHub App avec Actions Runner Controller (ARC) via SealedSecrets

## 1. Création de la GitHub App

1. Aller dans **Settings > Developer Settings > GitHub Apps**  
   👉 https://github.com/settings/apps

2. Cliquer sur **New GitHub App** et remplir :
   - **App name** : `arc-logo` (ou autre nom)
   - **Homepage URL** : `https://github.com/loicgo29`
   - **Callback URL** : `https://example.com/callback` (obligatoire mais pas utilisé ici)
   - **Webhook URL** : `https://nudger.logo-solutions.fr`
   - **Webhook secret** : générer une valeur forte

3. Permissions :
   - Repository permissions : **Read & Write** sur `Actions`, `Administration`, `Checks`
   - Metadata : **Read-only**

4. Installation :
   - Restreindre à **compte @loicgo29**
   - Accès à **tous les repos**

5. Récupérer :
   - **App ID** : `1977125`
   - **Installation ID** : visible ici 👉 https://github.com/settings/installations → `86589867`
   - **Private Key** : générer et télécharger (`.pem`)

---

## 2. Préparation du fichier clé privée

Créer un fichier **local** (non versionné dans Git !) :

```bash
vim gh-app.pem
```

Coller dedans le contenu complet :

```
-----BEGIN RSA PRIVATE KEY-----
MI...
-----END RSA PRIVATE KEY-----
```

⚠️ Ne pas committer ce fichier.

---

## 3. Génération du Secret Kubernetes

On génère un secret **non-appliqué** en YAML :

```bash
kubectl -n arc-system create secret generic controller-manager   --from-literal=github_app_id=1977125   --from-literal=github_app_installation_id=86589867   --from-file=github_app_private_key=./gh-app.pem   --dry-run=client -o yaml > app.yaml
```

Vérifier `app.yaml` contient bien :
```yaml
stringData:
  github_app_id: "1977125"
  github_app_installation_id: "86589867"
  github_app_private_key: |-
    -----BEGIN RSA PRIVATE KEY-----
    ...
    -----END RSA PRIVATE KEY-----
```

---

## 4. Scellement avec SealedSecrets

1. Vérifier que le contrôleur est bien déployé :
```bash
kubectl -n kube-system get pods | grep sealed-secrets
kubectl -n kube-system get svc | grep sealed-secrets
```

2. Transformer le Secret en **SealedSecret** :
```bash
kubectl -n arc-system create secret generic controller-manager   --from-literal=github_app_id=1977125   --from-literal=github_app_installation_id=86589867   --from-file=github_app_private_key=./gh-app.pem   --dry-run=client -o yaml | kubeseal   --controller-name=sealed-secrets   --controller-namespace=kube-system   --format=yaml > infra/action-runner-controller/base/secret-controller-manager-sealed.yaml
```

3. Vérifier que le fichier n’est **pas vide** :
```bash
sed -n '1,40p' infra/action-runner-controller/base/secret-controller-manager-sealed.yaml
```

Il doit commencer par :
```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: controller-manager
  namespace: arc-system
spec:
  encryptedData:
    github_app_id: Ag...
    github_app_installation_id: Ag...
    github_app_private_key: Ag...
```

---

## 5. Application dans le cluster

Committer le fichier **sealed** :
```bash
git add infra/action-runner-controller/base/secret-controller-manager-sealed.yaml
git commit -m "feat: add ARC sealed secret for GitHub App"
git push
```

Flux appliquera automatiquement le `SealedSecret`, qui générera le `Secret` déchiffré dans `arc-system`.

---

## 6. Vérifications

```bash
kubectl -n arc-system get sealedsecrets
kubectl -n arc-system get secret controller-manager -o yaml
kubectl -n arc-system get pods
kubectl -n arc-system logs deploy/actions-runner-controller -c manager --tail=50
```

✅ Tu dois voir un pod `actions-runner-controller` en **Running (2/2)**, sans erreur `dummy`.

---

## 7. Nettoyage (sécurité)

Après scellement :
```bash
rm gh-app.pem
rm app.yaml
```

⚠️ Garder seulement `secret-controller-manager-sealed.yaml` dans Git.

---

# ✅ Résumé

- GitHub App créée (`arc-logo`)
- App ID : `1977125`
- Installation ID : `86589867`
- Clé privée gérée via **SealedSecrets**
- Secret `controller-manager` sécurisé et appliqué en GitOps

