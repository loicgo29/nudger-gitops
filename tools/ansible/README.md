# tools/ansible — Générateur GitOps (pas de kubectl apply)
- Ce dossier sert à **générer/valider** des manifests dans le repo (ex: Longhorn), puis **ouvrir une PR**.
- **INTERDIT** : déployer sur le cluster. Les apply sont faits par **Flux**.
- Cibles Makefile :
  - `make gen`      → génère/MAJ les manifests (ex: infra/longhorn/**)
  - `make validate` → kustomize build + kubeval/kubelinter (local)
  - `make pr`       → commit/push branche + PR GitHub (nécessite GH_TOKEN)
