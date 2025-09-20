# 1. Supprimer le HelmChart en cache
kubectl -n flux-system delete helmchart arc-system-actions-runner-controller --ignore-not-found

# 2. Supprimer le HelmRelease (au cas où l’ancien état reste collé)
kubectl -n arc-system delete helmrelease actions-runner-controller --ignore-not-found

# 3. Re-synchroniser la source Helm
flux reconcile source helm actions-runner-controller -n flux-system

# 4. Re-synchroniser le HelmRelease
flux reconcile helmrelease actions-runner-controller -n arc-system

# 5. Vérifier l’état
kubectl -n flux-system get helmcharts | grep arc-system-actions-runner-controller || true
kubectl -n arc-system get helmreleases | grep actions-runner-controller || true
