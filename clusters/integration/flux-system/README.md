# Procédure de réinstallation FluxCD (namespace flux-system)

Cette procédure décrit comment réparer/recréer un déploiement FluxCD propre dans un cluster Kubernetes,
en s’appuyant sur un repository Git déjà existant (`loicgo29/nudger-gitops`).

---

## 1. Nettoyage de l’ancien répertoire

```bash
rm -rf clusters/integration/flux-system/
mkdir -p clusters/integration/flux-system
```

---

## 2. Réinstaller les composants Flux (gotk-components.yaml)

```bash
flux install   --namespace=flux-system   --network-policy=false   --export > clusters/integration/flux-system/gotk-components.yaml
```

Ce fichier contient :
- CRDs FluxCD (source, kustomize, helm, notification…)
- RBAC et ClusterRoles
- Deployments (source-controller, kustomize-controller, helm-controller, notification-controller)
- Services associés

---

## 3. Créer la ressource de synchronisation (gotk-sync.yaml)

`clusters/integration/flux-system/gotk-sync.yaml` :

```yaml
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 1m
  url: ssh://git@github.com/loicgo29/nudger-gitops
  ref:
    branch: main
  secretRef:
    name: flux-system
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 10m
  path: ./clusters/integration
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
```

---

## 4. Kustomization locale

`clusters/integration/flux-system/kustomization.yaml` :

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - gotk-components.yaml
  - gotk-sync.yaml
```

---

## 5. Application initiale

```bash
kubectl apply -k clusters/integration/flux-system
```

Exemple de sortie :
```
namespace/flux-system unchanged
serviceaccount/source-controller created
deployment.apps/source-controller created
kustomization.kustomize.toolkit.fluxcd.io/flux-system created
gitrepository.source.toolkit.fluxcd.io/flux-system created
```

---

## 6. Vérifications

Forcer une réconciliation :

```bash
flux reconcile source git flux-system -n flux-system
flux get kustomizations -A
```

Logs utiles :

```bash
kubectl -n flux-system logs deploy/source-controller
kubectl -n flux-system logs deploy/kustomize-controller
```

---

✅ Après ces étapes, le namespace `flux-system` est propre, les CRDs sont à jour,
et FluxCD resynchronise le dossier `clusters/integration/` avec le repo Git.

