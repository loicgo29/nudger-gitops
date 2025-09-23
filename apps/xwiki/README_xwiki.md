# 📘 Déploiement XWiki 17.3.0 (Tomcat + MySQL)

## 🎯 Objectif
Déployer **XWiki 17.3.0** sur Kubernetes avec :
- **1 réplique** (StatefulSet)
- **Base de données MySQL externe** (`mysql-xwiki`)
- **Stockage persistant** pour `/usr/local/xwiki/data`
- **Ingress** HTTPS avec Let’s Encrypt
- **Probes** pour supervision et redémarrage automatique

---

## 📂 Arborescence GitOps

```
apps/xwiki/
  base/
    kustomization.yaml
    xwiki-statefulset.yaml
    xwiki-service.yaml
    xwiki-ingress.yaml
  overlays/
    recette/
      kustomization.yaml
```

---

## ⚙️ Composants

### 1. StatefulSet `xwiki`
- Image : `xwiki:17.3.0-mysql-tomcat`
- Variables d’env :
  - `DB_HOST=mysql-xwiki`
  - `DB_DATABASE=xwiki`
  - `DB_USER` / `DB_PASSWORD` (secret `mysql-xwiki-secret`)
- Volume : `xwiki-data` monté sur `/usr/local/xwiki/data`
- Probes :
  - **Readiness** : `http://:8080/bin/view/Main/WebHome`
  - **Liveness** : `http://:8080/`

### 2. Service `xwiki-svc`
- Type : `ClusterIP`
- Port : `8080`

### 3. Ingress
- Host : `xwiki.nudger.logo-solutions.fr`
- TLS : `letsencrypt-prod` (`xwiki-tls`)

---

## 🚀 Déploiement

### Avec kubectl
```bash
kubectl apply -k apps/xwiki/overlays/recette
```

### Avec Flux
```bash
flux reconcile kustomization xwiki -n flux-system --with-source
```

---

## 🔍 Tests

### 1. Vérifier le pod
```bash
kubectl -n ns-open4goods-recette get pods -l app=xwiki
```

### 2. Vérifier l’accès interne
```bash
kubectl -n ns-open4goods-recette port-forward svc/xwiki-svc 8080:8080
curl -f http://localhost:8080/
```

### 3. Vérifier l’accès externe
```bash
curl -vk https://xwiki.nudger.logo-solutions.fr/
```

---

## 🧪 Smoke test XWiki
Un Job Kubernetes peut tester que l’URL `/` retourne HTTP 200 :

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: xwiki-smoke
  namespace: ns-open4goods-recette
spec:
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: curl
        image: curlimages/curl:8.9.0
        command: ["sh", "-c"]
        args:
          - curl -fsSL http://xwiki-svc:8080/ > /dev/null
```

Lancer le test :
```bash
kubectl -n ns-open4goods-recette apply -f smoke-tests/xwiki-smoke.yaml
kubectl -n ns-open4goods-recette logs -l job-name=xwiki-smoke --tail=50
```

---

## ✅ Persistance
1. Créer une page dans XWiki.  
2. Supprimer le pod :
   ```bash
   kubectl -n ns-open4goods-recette delete pod -l app=xwiki
   ```
3. Vérifier que la page est toujours présente après redémarrage.

---

## 📌 Definition of Done (DoD)
- Manifests versionnés dans `nudger-gitops`
- Pod XWiki **Running** et accessible en HTTP(S)
- Données persistantes après redémarrage
- Documentation disponible (`README-xwiki.md`)
- Smoke-test validé

