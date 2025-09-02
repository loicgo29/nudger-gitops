# Diff et dry-run sur whoami
DIR=apps/whoami scripts/diff.sh
MODE=server DIR=apps/whoami scripts/dry-run.sh

# Reconcile complet (source + kustomizations)
scripts/flux-reconcile.sh

# Forcer un run d’ImageUpdateAutomation
AUTONAME=whoami-update scripts/flux-annotate.sh

# Rendu que Flux appliquerait pour la Kustomization 'apps'
KZ=apps scripts/flux-build.sh

# Ouvrir/MAJ une PR (si commits ahead)
AUTO_UPDATE_BRANCH=flux-imageupdates BASE_BRANCH=main scripts/pr-open.sh

# Lancer le workflow auto-PR en manuel
AUTO_UPDATE_BRANCH=flux-imageupdates scripts/pr-workflow.sh

# Nettoyer les branches flux-imageupdates-*
scripts/pr-clean.sh

# Installer les outils (si pas déjà là)
scripts/tools-kustomize.sh
scripts/tools-kubeconform.sh

