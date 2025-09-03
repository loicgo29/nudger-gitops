#!/usr/bin/env bash
# bump-whoami.sh — Patch un kustomization.yaml pour forcer l'image/tag, commit, push, et créer une PR.
# Équiv. au workflow GitHub Actions "🔧 Bump whoami (Kustomize)".

set -euo pipefail

### --- Paramètres (par défauts raisonnables, override via --flags) ----------------
FILE="apps/whoami/kustomization.yaml"    # chemin du kustomization ciblé
NAME="whoami"                             # .images[].name à patcher/insérer
REPO="traefik/whoami"                     # newName
TAG=""                                    # newTag -> OBLIGATOIRE
BASE_BRANCH="main"                        # branche de base pour la PR
BRANCH="chore/whoami-bump-$(date +%Y%m%d-%H%M%S)"  # branche de travail
PR_LABELS=("auto" "whoami" "kustomize")   # labels de la PR

### --- Parse des arguments --------------------------------------------------------
usage() {
  cat <<EOF
Usage: $0 --image-repo REPO --image-tag TAG [--file PATH] [--name whoami] [--base main] [--branch BRANCH]
Exemples:
  $0 --image-repo traefik/whoami --image-tag v1.10.1
  $0 --image-repo ghcr.io/loicgo29/nudger-whoami --image-tag 2025.09.03-a1b2c3d

Options:
  --image-repo   (obligatoire) Valeur pour .images[].newName
  --image-tag    (obligatoire) Valeur pour .images[].newTag
  --file         (optionnel)   kustomization à patcher (défaut: $FILE)
  --name         (optionnel)   .images[].name ciblé (défaut: $NAME)
  --base         (optionnel)   branche base PR (défaut: $BASE_BRANCH)
  --branch       (optionnel)   nom de branche travail (défaut: $BRANCH)
  -h|--help                  Affiche cette aide
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image-repo) REPO="${2:-}"; shift 2;;
    --image-tag)  TAG="${2:-}";  shift 2;;
    --file)       FILE="${2:-}"; shift 2;;
    --name)       NAME="${2:-}"; shift 2;;
    --base)       BASE_BRANCH="${2:-}"; shift 2;;
    --branch)     BRANCH="${2:-}"; shift 2;;
    -h|--help)    usage; exit 0;;
    *) echo "Arg inconnu: $1"; usage; exit 2;;
  esac
done
cd ../..
# Sanity checks basiques
[[ -z "$REPO" ]] && { echo "Erreur: --image-repo est obligatoire"; exit 2; }
[[ -z "$TAG"  ]] && { echo "Erreur: --image-tag est obligatoire"; exit 2; }
[[ -f "$FILE" ]] || { echo "Introuvable: $FILE"; exit 1; }

### --- Vérifs d’environnement -----------------------------------------------------
# 1) Dans un repo Git ?
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Pas dans un repo git."; exit 1; }

# 2) yq v4 dispo ?
if ! command -v yq >/dev/null 2>&1; then
  echo "yq non trouvé. Installation rapide (sudo requis)..."
  sudo wget -qO /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/v4.44.3/yq_linux_amd64"
  sudo chmod +x /usr/local/bin/yq
fi

# 3) On note si gh CLI est dispo (pour la PR)
HAS_GH=1
command -v gh >/dev/null 2>&1 || HAS_GH=0

### --- Création de la branche de travail ----------------------------------------
# On part de la base, on se met à jour, et on crée la branche
git fetch origin --prune
git checkout "$BASE_BRANCH"
git pull --ff-only origin "$BASE_BRANCH"
git checkout -b "$BRANCH"

### --- Patch du kustomization.yaml ----------------------------------------------
# Objectif : assurer la présence de .images[], puis
# - si .images[].name == NAME existe -> maj newName/newTag
# - sinon -> append une nouvelle entrée
echo "Patch de: $FILE (name=$NAME, newName=$REPO, newTag=$TAG)"

# Garantir le bloc images[]
if ! yq '.images' "$FILE" >/dev/null 2>&1; then
  yq -i '.images = []' "$FILE"
fi

# Update/insert par name
if yq '.images[] | select(.name == env(NAME))' "$FILE" >/dev/null 2>&1; then
  yq -i '
    (.images[] | select(.name == env(NAME)).newName) = env(REPO) |
    (.images[] | select(.name == env(NAME)).newTag)  = env(TAG)
  ' "$FILE"
else
  yq -i '.images += [{"name": env(NAME), "newName": env(REPO), "newTag": env(TAG)}]' "$FILE"
fi

### --- Commit & push -------------------------------------------------------------
# On prépare un message fidèle au workflow
COMMIT_MSG="chore($NAME): bump to $REPO:$TAG"
TITLE="chore($NAME): $REPO:$TAG"
BODY="Path: \`$FILE\`"

# Ajout/commit
git add "$FILE"
# Si rien à commiter (pas de diff), on évite une PR inutile
if git diff --cached --quiet; then
  echo "Aucun changement (déjà sur $REPO:$TAG). Rien à faire."
  exit 0
fi

git commit -m "$COMMIT_MSG"
git push -u origin "$BRANCH"

### --- Création de la PR (si gh dispo) ------------------------------------------
if [[ $HAS_GH -eq 1 ]]; then
  echo "Création de la PR via gh CLI…"
  # Ajoute les labels si possible (ignoré si droits insuffisants)
  LABELS_CSV="$(IFS=,; echo "${PR_LABELS[*]}")"
  gh pr create \
    --base "$BASE_BRANCH" \
    --head "$BRANCH" \
    --title "$TITLE" \
    --body  "$BODY" \
    --label "$LABELS_CSV" || {
      echo "gh pr create a échoué. Crée la PR manuellement depuis $BRANCH."
      exit 0
    }
  echo "PR créée."
else
  echo "gh CLI indisponible : PR non créée automatiquement."
  echo "Crée une PR depuis la branche: $BRANCH -> base: $BASE_BRANCH"
fi

