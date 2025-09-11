#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"
shift || true

echo "── Scan des manifests dans: $ROOT ─────────────────────────────"

TOTAL=0
DIFFS=0
MISSING=0

# Trouve tous les .yaml/.yml/.json (sans -L pour compat POSIX)
# On ignore .git
while IFS= read -r -d '' f; do
  echo "📂 Fichier: $f"

  # Compte les documents avec yq (1 ligne par doc grâce à documentIndex)
  # Si yq n'imprime rien, DOCS=0
  DOCS=$(yq eval -d'*' 'documentIndex' "$f" 2>/dev/null | wc -l | tr -d '[:space:]')
  echo "🔎 DEBUG: $f contient $DOCS document(s)"

  if [[ "$DOCS" -eq 0 ]]; then
    # Pas un manifeste (kustomization params, values helm, etc.)
    echo "❌ Pas de document K8s détecté dans ce fichier"
    continue
  fi

  # Boucle sur chaque document via son index
  for i in $(yq eval -d'*' 'documentIndex' "$f" 2>/dev/null); do
    apiVersion=$(yq eval -d"$i" '.apiVersion // ""' "$f" 2>/dev/null || echo "")
    kind=$(yq eval -d"$i" '.kind // ""' "$f" 2>/dev/null || echo "")
    name=$(yq eval -d"$i" '.metadata.name // ""' "$f" 2>/dev/null || echo "")
    ns=$(yq eval -d"$i" '.metadata.namespace // ""' "$f" 2>/dev/null || echo "")

    # Filtre: on ne traite que les vrais objets K8s
    if [[ -z "$apiVersion" || -z "$kind" || -z "$name" ]]; then
      echo "   ↪︎ Doc #$i ignoré (apiVersion/kind/name manquants)"
      continue
    fi

    TOTAL=$((TOTAL+1))
    header="$kind/$name"
    [[ -n "$ns" ]] && header="$header -n $ns"
    echo "🔎 $header"

    # Vérifie si l'objet existe côté live (pour éviter les messages 'No resources found')
    if [[ -n "$ns" ]]; then
      if ! kubectl get "$kind" "$name" -n "$ns" >/dev/null 2>&1; then
        echo "⭕ Live manquant: $header"
        MISSING=$((MISSING+1))
        # On peut quand même faire diff -f -, kubectl marquera un create
      fi
      # Diff: on pipe uniquement ce document
      if ! yq eval -d"$i" '.' "$f" | kubectl diff -f - -n "$ns" >/dev/null 2>&1; then
        # kubectl diff renvoie 1 s'il y a des diff, 0 sinon, >1 si erreur
        status=$?
        if [[ "$status" -eq 1 ]]; then
          echo "⚠️  Diff détecté pour $header"
          DIFFS=$((DIFFS+1))
          # Affiche le diff lisible
          yq eval -d"$i" '.' "$f" | kubectl diff -f - -n "$ns" || true
        else
          echo "❌ Erreur kubectl diff pour $header (code $status)"
        fi
      else
        echo "✅ Pas de diff pour $header"
      fi
    else
      # cluster-scoped
      if ! kubectl get "$kind" "$name" >/dev/null 2>&1; then
        echo "⭕ Live manquant: $header"
        MISSING=$((MISSING+1))
      fi
      if ! yq eval -d"$i" '.' "$f" | kubectl diff -f - >/dev/null 2>&1; then
        status=$?
        if [[ "$status" -eq 1 ]]; then
          echo "⚠️  Diff détecté pour $header"
          DIFFS=$((DIFFS+1))
          yq eval -d"$i" '.' "$f" | kubectl diff -f - || true
        else
          echo "❌ Erreur kubectl diff pour $header (code $status)"
        fi
      else
        echo "✅ Pas de diff pour $header"
      fi
    fi
  done

done < <(find "$ROOT" -type f \( -name '*.yaml' -o -name '*.yml' -o -name '*.json' \) ! -path '*/.git/*' -print0)

echo
echo "── Résumé ─────────────────────────────"
echo "📄 Docs comparés: $TOTAL   🔍 Diffs: $DIFFS   ⭕ Manquants (live): $MISSING"
