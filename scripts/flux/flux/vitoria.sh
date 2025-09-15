flux reconcile source git gitops -n flux-system
flux reconcile source helm victoria-metrics -n flux-system
flux reconcile kustomization observability -n flux-system --with-source
kubectl get kustomizations.kustomize.toolkit.fluxcd.io -A
kubectl get helmrelease -n logging

