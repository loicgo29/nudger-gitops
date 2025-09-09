# 1) Vérifie la config responsable du blocage (facultatif)
git config --show-origin --get pull.ff

# 2) Mets à jour les refs distantes
git fetch origin

# 3) Rebase tes commits locaux sur la tête distante
git rebase origin/main

# (Résous les conflits si besoin: édite -> `git add <fichiers>` -> `git rebase --continue`)

# 4) Pousse le résultat (sécurisé)
git push --force-with-lease

