# a) suspend / resume (réinitialise la boucle)
flux suspend kustomization ingress-nginx -n flux-system
flux resume  kustomization ingress-nginx -n flux-system

# b) poke explicite (au cas où)
kubectl -n flux-system annotate kustomization ingress-nginx \
  reconcile.fluxcd.io/requestedAt="$(date -u +%FT%TZ)" --overwrite

# c) assure la source Git à jour et visible
flux reconcile kustomization sources -n flux-system --with-source
flux reconcile source git gitops -n flux-system
