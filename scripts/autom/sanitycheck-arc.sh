# Vérifie que toutes les Kustomizations Flux sont OK
kubectl -n flux-system get kustomizations

# Vérifie spécifiquement arc-repo et arc-release
kubectl -n flux-system get kustomization arc-repo arc-release

# Vérifie que le HelmRelease est Ready
kubectl -n arc-systems get helmrelease actions-runner-controller

# Vérifie que le déploiement est bien en place et les pods démarrés
kubectl -n arc-systems get deploy,pods -o wide

# Vérifie que le secret PAT GitHub (controller-manager) existe
kubectl -n arc-systems get secret controller-manager

# Vérifie le certificat TLS du webhook ARC
kubectl -n arc-systems get certificate actions-runner-controller-serving-cert

# Si tout est OK, tu dois voir :
# - Kustomizations "Ready"
# - HelmRelease "Ready=True"
# - 1/1 pod(s) Running
# - secrets présents
# - certificat "Ready=True"@

