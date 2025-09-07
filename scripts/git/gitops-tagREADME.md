Pourquoi ce script est “le mieux” pour ton contexte
	•	Traçabilité forte (date/heure UTC + commit + auteur + range des commits).
	•	Scope auto (apps/…, infra/…, etc.) pour comprendre où ça a bougé — et “multi” si global.
	•	Type auto (breaking/feat/fix/misc) compatible conventions de commit.
	•	Anti-collision via suffixe -rN si tu tags plusieurs fois la même minute/scope/type.
	•	Sécurisé (set -euo pipefail) + options --dry-run et --no-push.

Exemples

# Tag normal + push
scripts/gitops-tag.sh
# ➜ v20250906-2010-whoami-feat-r1

# Forcer le scope et faire un dry-run
scripts/gitops-tag.sh --scope ingress --dry-run

# Créer localement sans push
scripts/gitops-tag.sh --no-push
