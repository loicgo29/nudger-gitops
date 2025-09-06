git checkout main
git pull --ff-only
git merge --no-ff feat/20250906-flux3
git push origin main
git branch -d feat/20250906-flux3
