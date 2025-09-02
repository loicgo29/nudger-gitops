# Forcer ImageUpdateAutomation
kubectl -n flux-system annotate imageupdateautomation whoami-update \
  reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite

# Forcer la source GitOps
flux reconcile source git gitops -n flux-system

# Forcer toutes les Kustomizations (méthode la plus simple)
kubectl get kustomization -A -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' \
| while read ns name; do
  kubectl -n "$ns" annotate --overwrite kustomization "$name" \
    reconcile.fluxcd.io/requestedAt="$(date +%s)"
done

# Petit check
kubectl get kustomization -A
flux get kustomizations -A


# pull Git
flux reconcile source git gitops -n flux-system

# forcer les Kustomization (avec namespace)
kubectl get kustomization -A -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' \
| while read ns name; do
  flux reconcile kustomization "$name" -n "$ns"
done

# vérifier
flux get kustomizations -A

