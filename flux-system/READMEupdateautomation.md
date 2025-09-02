Il résume le process “normal” avec Flux Image Automation, plus 1–2 commandes utiles.

# GitOps + Flux: Auto-bump d’images

## Rôles des branches
- **main** : source de vérité. Ce qui est mergé ici est déployé par Flux.
- **flux-imageupdates** : branche *technique* alimentée **uniquement** par Flux pour proposer des bumps d’images → PR vers `main`.

## Cycle normal (recommandé)
1. Tu ne touches pas `newTag:` à la main.
2. `ImagePolicy` détecte une image plus récente (selon `spec.filterTags`/semver).
3. `ImageUpdateAutomation` pousse un commit dans `flux-imageupdates` (mise à jour de `newTag` via les *setters*).
4. Le workflow GitHub ouvre une **PR** vers `main`.
5. Tu review/CI/merge → Flux applique `main` dans le cluster.

## Setters attendus (ex: apps/whoami/kustomization.yaml)
```yaml
images:
  - name: traefik/whoami
    newName: traefik/whoami # {"$imagepolicy": "flux-system:whoami:name"}
    newTag: v1.10.1         # {"$imagepolicy": "flux-system:whoami:tag"}

Modifs manuelles (rollback / pin)

Tu peux changer newTag: dans main pour pinner/rollback.

Flux appliquera immédiatement cette version.

Si l’automate est actif, il reproposera une PR vers la “dernière” version selon la policy.

Pour pinner temporairement :

kubectl -n flux-system patch imageupdateautomation whoami-update --type merge -p '{"spec":{"suspend":true}}'
# ... quand OK pour reprendre les bumps :
kubectl -n flux-system patch imageupdateautomation whoami-update --type merge -p '{"spec":{"suspend":false}}'

Vérifs rapides
# Ce que Flux considère comme "dernier tag"
kubectl -n flux-system get imagepolicy whoami -o jsonpath='{.status.latestImage}{"\n"}'

# Ce que rend main
kustomize build apps/whoami | grep 'image:'

# Forcer un run de l’automate images
kubectl -n flux-system annotate imageupdateautomation whoami-update \
  reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite

# Y a-t-il un commit à PR ?
git fetch origin
git rev-list --count origin/main..origin/flux-imageupdates

Ne pas faire

Ne jamais merge/pusher main → flux-imageupdates. Cette branche doit rester gérée par Flux.

Ne pas retirer les commentaires setters # {"$imagepolicy": ...} : sans eux, l’automate ne met plus à jour.

Troubleshooting

Pas de PR alors qu’une image plus récente existe ?

Vérifie que origin/main..origin/flux-imageupdates >= 1.

Vérifie les logs :
kubectl -n flux-system logs deploy/image-automation-controller --since=10m

Si la branche technique est “cassée”, recrée-la proprement :

git push origin :flux-imageupdates
kubectl -n flux-system annotate imageupdateautomation whoami-update reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite
