#!/usr/bin/env bash
set -euo pipefail

SITES_DEFAULT=(
  "%openai.com%"
  "%oaiusercontent.com%"
  "%chat.openai.com%"
  "%auth.openai.com%"
  "%platform.openai.com%"
)

BROWSER_NAME="Brave Browser"
BRAVE_DIR="$HOME/Library/Application Support/BraveSoftware/Brave-Browser"

# --- options ---
DRYRUN="0"
FORCE="0"
SITES=("${SITES_DEFAULT[@]}")

usage() {
  echo "Usage: $0 [--dry-run] [--force] [--site '%domaine%']..."
  echo "  --dry-run   : affiche ce qui serait supprimé, ne modifie rien"
  echo "  --force     : tue Brave si ne se ferme pas en 5s"
  echo "  --site      : ajoute un motif de domaine SQLite LIKE (répétable)."
  echo "                Par défaut: ${SITES_DEFAULT[*]}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRYRUN="1"; shift ;;
    --force)   FORCE="1"; shift ;;
    --site)    SITES+=("$2"); shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Option inconnue: $1"; usage; exit 1 ;;
  esac
done

ensure_tools() {
  command -v sqlite3 >/dev/null || { echo "sqlite3 requis. Installe-le (ex: brew install sqlite)."; exit 1; }
}

quit_brave() {
  # ferme proprement
  osascript -e "tell application \"$BROWSER_NAME\" to quit" >/dev/null 2>&1 || true
  for _ in {1..10}; do
    if ! pgrep -f "$BROWSER_NAME" >/dev/null 2>&1; then return 0; fi
    sleep 0.5
  done
  if [[ "$FORCE" == "1" ]]; then
    echo "Brave ne s'est pas fermé : kill..."
    pkill -f "$BROWSER_NAME" || true
    sleep 1
  else
    echo "Brave semble encore ouvert. Relance avec --force si besoin."
    exit 1
  fi
}

build_where_clause() {
  local -n arr=$1
  local parts=()
  for s in "${arr[@]}"; do
    parts+=("host_key LIKE '$s'")
  done
  local IFS=" OR "
  echo "${parts[*]}"
}

process_db() {
  local db="$1"
  [[ -f "$db" ]] || return 0

  local ts
  ts="$(date +%Y%m%d-%H%M%S)"
  local backup="${db}.bak-${ts}"

  local where
  where="$(build_where_clause SITES)"

  echo "→ Profil: $(dirname "$db")"
  if [[ "$DRYRUN" == "1" ]]; then
    echo "  * DRY-RUN: affichage des cookies visés:"
    sqlite3 "$db" "SELECT host_key, name FROM cookies WHERE $where;" || true
    return 0
  fi

  # sauvegarde
  cp "$db" "$backup"
  echo "  * Sauvegarde: $backup"

  # nettoyage + compactage
  sqlite3 "$db" <<SQL
PRAGMA journal_mode=WAL;
DELETE FROM cookies WHERE $where;
PRAGMA wal_checkpoint(FULL);
VACUUM;
SQL

  echo "  * Supprimé & compacté."
}

main() {
  ensure_tools
  [[ -d "$BRAVE_DIR" ]] || { echo "Dossier Brave introuvable: $BRAVE_DIR"; exit 1; }

  echo "Fermeture de Brave…"
  quit_brave

  # profils : Default, Profile 1, etc.
  mapfile -t DBS < <(find "$BRAVE_DIR" -maxdepth 2 -type f -name Cookies 2>/dev/null | sort)
  if [[ ${#DBS[@]} -eq 0 ]]; then
    echo "Aucune base Cookies trouvée."
    exit 0
  fi

  for db in "${DBS[@]}"; do
    process_db "$db"
  done

  echo "✅ Terminé."
}

main "$@"

