#!/usr/bin/env bash
set -euo pipefail

# --- usage ---
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <racine_manifests> [--reconcile] [--ns <namespace>] [--kinds <K1,K2,...>] [--debug]"
  exit 2
fi

ROOT="$1"; shift || true
RECONCILE=0; ONLY_NS=""; ONLY_KINDS=""; DEBUG=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --reconcile) RECONCILE=1;;
    --ns)        shift; ONLY_NS="${1:-}";;
    --kinds)     shift; ONLY_KINDS="${1:-}";;
    --debug)     DEBUG=1;;
    *) echo "arg inconnu: $1" >&2;;
  esac
  shift || true
done

dbg(){ [[ $DEBUG -eq 1 ]] && echo -e "🔎 DEBUG: $*"; }

strip_common(){
  # on normalise pour éviter les faux positifs de diff
  yq -P '
    del(
      .metadata.managedFields,
      .metadata.creationTimestamp,
      .metadata.resourceVersion,
      .metadata.uid,
      .metadata.generation,
      .metadata.annotations."kubectl.kubernetes.io/last-applied-configuration",
      .status
    )
  '
}

echo "── Scan des manifests dans: $ROOT ─────────────────────────────"

# (facultatif) reconcile flux
if [[ $RECONCILE -eq 1 ]] && command -v flux >/dev/null 2>&1; then
  echo "── Flux reconcile (toutes les Kustomizations) ─────────────────────────────"
  flux -n flux-system get ks -o name | awk '{print $1}' | while read -r KS; do
    ns="${KS%%/*}"; name="${KS##*/}"
    flux -n "$ns" reconcile kustomization "$name" --with-source || true
  done
fi

TOTAL=0
DIFFS=0
MISSING=0

# boucle fichiers YAML/YML
# Pas de -L, compat posix
while IFS= read -r -d '' f; do
  echo "📂 Fichier: $f"
  # on parcourt les documents avec documentIndex
  mapfile -t DOCS < <(yq -r -d'*' '
    [ (.kind // ""),
      (.metadata.name // ""),
      (.metadata.namespace // ""),
      (documentIndex)
    ] | @tsv
  ' "$f" 2>/dev/null || true)

  if [[ ${#DOCS[@]} -eq 0 ]]; then
    dbg "$f ne contient aucun doc YAML (ou non parsable)"; continue
  fi

  for line in "${DOCS[@]}"; do
    IFS=$'\t' read -r KIND NAME NS IDX <<<"$line"

    # skip si pas un manifeste K8s valide
    [[ -z "$KIND" || -z "$NAME" ]] && continue

    # filtres optionnels
    if [[ -n "$ONLY_KINDS" ]]; then
      IFS=',' read -r -a KARR <<<"$ONLY_KINDS"
      KEEP=0
      for k in "${KARR[@]}"; do [[ "$KIND" == "$k" ]] && KEEP=1; done
      [[ $KEEP -eq 0 ]] && continue
    fi
    if [[ -n "$ONLY_NS" ]]; then
      # ressources cluster-scoped => NS vide → on exclut si un NS est demandé
      [[ "$NS" != "$ONLY_NS" ]] && continue
    fi

    ((TOTAL++))
    # extrait le doc désiré (IDX) et normalise
    WANT="$(yq -d"$IDX" '.' "$f" | strip_common || true)"
    # détermine scope
    NSARG=()
    if [[ -n "$NS" ]]; then NSARG=(-n "$NS"); fi

    # vérifie existence live
    if ! kubectl "${NSARG[@]}" get "$KIND" "$NAME" >/dev/null 2>&1; then
      echo "⭕ Manquant (live): $KIND/$NAME ${NS:+-n $NS}"
      ((MISSING++))
      continue
    fi

    # récupère live normalisé
    LIVE="$(kubectl "${NSARG[@]}" get "$KIND" "$NAME" -o yaml | strip_common || true)"

    # diff: si différent, affiche un patch lisible
    if ! diff -u <(echo "$WANT") <(echo "$LIVE") >/dev/null 2>&1; then
      echo "⚠️  Diff détecté pour $KIND/$NAME ${NS:+-n $NS}"
      diff -u <(echo "$WANT") <(echo "$LIVE") || true
      ((DIFFS++))
    else
      dbg "OK: $KIND/$NAME ${NS:+-n $NS} — aucun diff"
    fi
  done
done < <(find "$ROOT" -type f \( -name '*.yaml' -o -name '*.yml' \) -print0)

echo
echo "── Résumé ─────────────────────────────"
echo "📄 Docs comparés: $TOTAL   🔍 Diffs: $DIFFS   ⭕ Manquants (live): $MISSING"
exit 0
