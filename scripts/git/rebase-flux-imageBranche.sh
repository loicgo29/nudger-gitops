git checkout main
git fetch origin
git reset --hard origin/main

# recrée/écrase flux-imageupdates sur le SHA exact de main
git branch -f flux-imageupdates origin/main
git push origin flux-imageupdates --force
