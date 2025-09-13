# Tester juste l'overlay Victoria-Metrics lab
kustomize build infra/victoria-metrics/overlays/lab 

# Tester tout l'overlay observability/lab (qui inclut Grafana, etc.)
kustomize build infra/observability/overlays/lab 

# Tester ce que Flux verrait pour lab (clusters/lab/kustomization.yaml)
kustomize build clusters/lab 

# Reconcile une seule Kustomization Flux
flux reconcile kustomization victoria-metrics -n flux-system --with-source

# Si tu veux tout l'env lab
flux reconcile kustomization observability -n flux-system --with-source
flux reconcile kustomization lab -n flux-system --with-source
