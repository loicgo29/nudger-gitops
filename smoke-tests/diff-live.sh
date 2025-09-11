#!/usr/bin/env bash
# diff-live.sh <ROOT> [--reconcile] [--only-kind=KIND] [--only-ns=NS]
set -euo pipefail

ROOT="${1:-.}"; shift || true
RECONCILE=0
ONLY_KIND=""
ONLY_NS=""

for arg in "$@"; do
  case "$arg" in
    --reconcile) RECONCILE=1 ;;
    --only-kind=*) ONLY_KIND="${arg#*=}" ;;
    --only-ns=*)   ONLY_NS="${arg#*=}" ;;
    *) ;;
  esac
done

RED=$'\e[31m'; GRN=$'\e[32m'; YEL=$'\e[33m'; BLU=$'\e[34m'; RST=$'\e[0m'
say()  { echo -e "$@"; }
pass() { echo -e "✅ ${GRN}$*${RST}"; }
warn() { echo -e "⚠️  ${YEL}$*${RST}"; }
fail() { echo -e "❌ ${RED}$*${RST}"; }

need() { command -v "$1" >/dev/null 2>&1 || { fail "binaire requis manquant: $1"; exit 3; }; }
need kubectl
need yq
command -v flux >/dev/null 2>&1 || true

if (( RECONCILE == 1 )) && command -v flux >/dev/null 2>&1; then
  say "${BLU}── Flux reconcile (toutes les Kustomizations) ─────────────────────────────${RST}"
  flux -n flux-system get ks -o name | xargs -r -n1 flux -n flux-system reconcile ks || true
fi

say "${BLU}── Scan des manifests dans: ${ROOT} ─────────────────────────────${RST}"

TOTAL=0
DIFFS=0
MISSING=0

# Liste “raisonnable” de kinds cluster-scoped (pas d’option -n)
is_cluster_scoped () {
  case "$1" in
    Namespace|Node|ClusterRole|ClusterRoleBinding|CustomResourceDefinition|StorageClass|PriorityClass|ClusterIssuer|MutatingWebhookConfiguration|ValidatingWebhookConfiguration)
      return 0 ;;
    *) return 1 ;;
  esac
}

# Boucle fichiers YAML/YML
while IFS= read -r f; do
  echo "📂 Fichier: $f"
  # Pour chaque document du fichier, yq imprime UNE ligne: KIND<TAB>NAME<TAB>NAMESPACE
  # yq v4 imprime une ligne par doc, même multi-doc, sans -d.
  mapfile -t lines < <(yq -r -N '.kind // "" + "\t" + (.metadata.name // "") + "\t" + (.metadata.namespace // "")' "$f" || true)

  for line in "${lines[@]}"; do
    # Ignore lignes vides (ex: commentaires ou doc vide)
    [[ -z "$line" ]] && continue
    kind="$(cut -f1 <<<"$line")"
    name="$(cut -f2 <<<"$line")"
    ns="$(cut -f3 <<<"$line")"

    # Si pas un “vrai” manifeste k8s
    [[ -z "$kind" || -z "$name" ]] && continue

    # Filtres optionnels
    if [[ -n "$ONLY_KIND" && "$kind" != "$ONLY_KIND" ]]; then
      continue
    fi
    if [[ -n "$ONLY_NS" && -n "$ns" && "$ns" != "$ONLY_NS" ]]; then
      continue
    fi

    ((TOTAL++))
    if is_cluster_scoped "$kind"; then
      scope_args=()
      ns_label=""
    else
      # namespace par défaut si non renseigné
      ns="${ns:-default}"
      scope_args=(-n "$ns")
      ns_label="-n $ns"
    fi

    echo "🔎 ${kind}/${name} ${ns_label}"

    # 1) Objet live existe ?
    if ! kubectl get "${scope_args[@]}" "$kind/$name" >/dev/null 2>&1; then
      warn "Manquant (live): ${kind}/${name} ${ns_label}"
      ((MISSING++))
    fi

    # 2) Diff live vs fichier (kubectl gère multi-doc si on lui passe tout le fichier,
    #    mais ici on re-sélectionne le doc avec yq via un filtre sur name/kind/namespace)
    #    → on extrait **uniquement** ce doc et on le passe à kubectl diff -f -
    doc_yaml="$(yq -N '
      select(.kind == "'"$kind"'")
      | select(.metadata.name == "'"$name"'")
      | select((.metadata.namespace // "") == "'"${ns:-}"'")
    ' "$f" 2>/dev/null || true)"

    if [[ -z "$doc_yaml" ]]; then
      # Si pas de namespace dans le doc (cluster-scoped), on relâche le filtre ns
      doc_yaml="$(yq -N '
        select(.kind == "'"$kind"'")
        | select(.metadata.name == "'"$name"'")
      ' "$f" 2>/dev/null || true)"
    fi

    if [[ -z "$doc_yaml" ]]; then
      warn "Impossible d’extraire le doc correspondant depuis $f (skip diff)"
      continue
    fi

    if kubectl diff "${scope_args[@]}" -f - >/dev/null 2>&1 <<<"$doc_yaml"; then
      pass "Pas de diff pour ${kind}/${name} ${ns_label}"
    else
      # kubectl diff retourne code 1 s’il y a des diffs
      ((DIFFS++))
      echo "${YEL}--- DIFF ${kind}/${name} ${ns_label} ---${RST}"
      kubectl diff "${scope_args[@]}" -f - <<<"$doc_yaml" || true
      echo "${YEL}--- END DIFF ---${RST}"
    fi
  done
done < <(find "$ROOT" -type f \( -name '*.yaml' -o -name '*.yml' \) ! -path '*/.git/*' -print | sort)

say "${BLU}── Résumé ─────────────────────────────${RST}"
echo "📄 Docs comparés: $TOTAL   🔍 Diffs: $DIFFS   ⭕ Manquants (live): $MISSING"
