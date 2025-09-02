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

DRYRUN="0"
FORCE="0"
SITES=("${SITES_DEFAULT[@]}")

usage() {
  echo "Usage: $0 [--dry-run] [--force] [--site '%domaine%']..."
  echo "  --dry-run   : n'effectue pas de suppression"
  echo "  --force     : kill Brave si non fermé"
  echo "  --site      : motif LIKE SQLite supplémentaire (répétable)"
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
  command -v sqlite3 >/dev/null || { echo "sqlite3 requis (ex: brew install sqlite)."; exit 1; }
}

quit_brave() {
  # ferme proprement
  osascript -e "tell application \"$BROWSER_NAME\" to quit" >/dev/null 2>&1 || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do
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
  local parts=()
  local s
  for s in "${SITES[@]}"; do
    parts+=("host_key LIKE '$s'")
  done
  local IFS=" OR "
  echo "${parts[*]}"
}

process_db() {
  local db="$1"
  [[ -f "$db" ]] || return 0

  local ts backup where
  ts="$(date +%Y%m%d-%H%M%S)"
  backup="${db}.bak-${ts}"
  where="$(build_where_clause)"

  echo "→ Profil: $(dirname "$db")"
  if [[ "$DRYRUN" == "1" ]]; then
    echo "  * DRY-RUN: cookies visés:"
    sqlite3 "$db" "SELECT host_key, name FROM cookies WHERE $where;" || true
    return 0
  fi

  cp "$db" "$backup"
  echo "  * Sauvegarde: $backup"

  sqlite3 "$db" <<'SQL'
PRAGMA journal_mode=WAL;
SQL

  sqlite3 "$db" "DELETE FROM cookies WHERE $where;"

  sqlite3 "$db" <<'SQL'
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

  # Parcours des DB sans process substitution
  found="0"
  IFS=$'\n'
  for db in $(find "$BRAVE_DIR" -maxdepth 2 -type f -name Cookies 2>/dev/null); do
    IFS=$' \t\n'  # reset IFS pour dirname/sqlite3
    process_db "$db"
    found="1"
    IFS=$'\n'
  done
  IFS=$' \t\n'
  if [[ "$found" = "0" ]]; then
    echo "Aucune base Cookies trouvée."
  else
    echo "✅ Terminé."
  fi
}

main "$@"

