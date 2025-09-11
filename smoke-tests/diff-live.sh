#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"
shift || true

echo "── Scan des manifests dans: $ROOT ─────────────────────────────"

TOTAL=0
DIFFS=0
MISSING=0

# find all yaml/json files
while IFS= read -r f; do
  echo "📂 Fichier: $f"

  # Count how many YAML docs are in this file
  DOCS=$(yq e '... comments="" | length' "$f" >/dev/null 2>&1 || true)
  # yq -d '*' walks each doc; we’ll probe them one by one
  i=0
  echo "DOCS $DOCS"
  while true; do
    # Extract basic fields of the i-th document
    apiVersion=$(yq -r -e "select(documentIndex == $i) | .apiVersion // empty" "$f" 2>/dev/null || true)
    [[ -z "${apiVersion}" ]] && break  # no more docs

    kind=$(yq -r "select(documentIndex == $i) | .kind // empty" "$f")
    name=$(yq -r "select(documentIndex == $i) | .metadata.name // empty" "$f")
    ns=$(yq -r "select(documentIndex == $i) | .metadata.namespace // empty" "$f")
echo "kind $kind name $name "
    # Skip docs without kind/name (values, params, dashboards, etc.)
    if [[ -z "$kind" || -z "$name" ]]; then
      echo "❌ Doc#$i ignoré (pas de kind/name)"
      i=$((i+1)); continue
    fi

    # Skip Kustomize config files (not live K8s objects)
    if [[ "$apiVersion" == kustomize.config.k8s.io/* ]]; then
      echo "⤵️  Doc#$i $kind/$name ignoré (Kustomize config)"
      i=$((i+1)); continue
    fi

    TOTAL=$((TOTAL+1))
    NS_ARG=()
    echo "$ns "
    [[ -n "$ns" ]] && NS_ARG=(-n "$ns")

    echo "🔎 Doc#$i $kind/$name ${ns:+-n $ns}"

    # Fetch live object
    set +e
    LIVE_YAML=$(kubectl get "$kind" "$name" "${NS_ARG[@]}" -o yaml 2>/dev/null)
    echo "------- $LIVE_YAML"
    rc=$?
    set -e

    if [[ $rc -ne 0 || -z "$LIVE_YAML" ]]; then
      echo "⭕ Manquant dans le cluster"
      MISSING=$((MISSING+1))
      i=$((i+1)); continue
    fi

    # Normalize both sides (sort keys deeply) then diff
    WANT_SORTED=$(yq eval 'sort_keys(..)' -d "$i" "$f" 2>/dev/null || true)
    LIVE_SORTED=$(echo "$LIVE_YAML" | yq eval 'sort_keys(..)')

    if diff -u <(echo "$WANT_SORTED") <(echo "$LIVE_SORTED") >/dev/null; then
      echo "✅ Identique au live"
    else
      echo "⚠️  Diff détecté pour $kind/$name"
      diff -u <(echo "$WANT_SORTED") <(echo "$LIVE_SORTED") | sed 's/^/    /' || true
      DIFFS=$((DIFFS+1))
    fi

    i=$((i+1))
  done
done < <(find "$ROOT" -type f \( -name '*.yaml' -o -name '*.yml' -o -name '*.json' \) ! -path '*/.git/*' -print)

echo
echo "── Résumé ─────────────────────────────"
echo "📄 Docs comparés: $TOTAL   🔍 Diffs: $DIFFS   ⭕ Manquants (live): $MISSING"
