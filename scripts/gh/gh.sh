#!/usr/bin/env bash
set -euo pipefail

# Nom du workflow par défaut
WORKFLOW="${WORKFLOW:-bump-whoami.yml}"

usage() {
  echo "Usage: $0 {list|view|logs|rerun|cancel} [run-id]"
  echo
  echo "Env var: WORKFLOW=$WORKFLOW"
  exit 1
}

list_runs() {
  gh run list --workflow="$WORKFLOW" --limit 5
}

view_run() {
  local run_id="${1:-}"
  if [[ -z "$run_id" ]]; then
    echo "Run ID manquant"
    exit 1
  fi
  gh run view "$run_id"
}

logs_run() {
  local run_id="${1:-}"
  if [[ -z "$run_id" ]]; then
    echo "Run ID manquant"
    exit 1
  fi
  gh run view "$run_id" --log
}

rerun_run() {
  local run_id="${1:-}"
  if [[ -z "$run_id" ]]; then
    echo "Run ID manquant"
    exit 1
  fi
  gh run rerun "$run_id"
}

cancel_run() {
  local run_id="${1:-}"
  if [[ -z "$run_id" ]]; then
    echo "Run ID manquant"
    exit 1
  fi
  gh run cancel "$run_id"
}

case "${1:-}" in
  list)   list_runs ;;
  view)   view_run "${2:-}" ;;
  logs)   logs_run "${2:-}" ;;
  rerun)  rerun_run "${2:-}" ;;
  cancel) cancel_run "${2:-}" ;;
  *)      usage ;;
esac
