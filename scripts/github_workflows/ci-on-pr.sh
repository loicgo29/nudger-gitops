#!/usr/bin/env bash
# ---------------------------------------------------------
# Script CI : Validation des manifests Kustomize avec kubeconform
# ---------------------------------------------------------
# Objectif : remplacer la logique du workflow GitHub Actions
# et centraliser ici la "vérité" CI pour usage local/CI.
#
# Étapes :
#   1. Vérifie / installe kustomize
#   2. Vérifie / installe kubeconform
#   3. Construit les manifests des répertoires cibles (apps/whoami, ingress-nginx/overlays/lab)
#   4. Valide avec kubeconform (strict, ignore missing schemas, summary)
#
# Variables d’env (surchage possibles dans CI ou en local) :
#   - KUSTOMIZE_VERSION (default: 5.4.2)
#   - KUBECONFORM_VERSION (default: 0.6.7)
#   - WORKDIR (par défaut: cwd)
#   - CHECK_WHOAMI (1/0, active ou non la validation apps/whoami)
#   - CHECK_INGRESS_LAB (1/0, active ou non la validation ingress-nginx/lab)
# ---------------------------------------------------------

set -euo pipefail

# --- Localiser la racine du repo et s'y placer ---
resolve_repo_root() {
  # 1) si on est dans un repo git
  if git rev-parse --show-toplevel >/dev/null 2>&1; then
    git rev-parse --show-toplevel
    return
  fi
  # 2) sinon: remonte depuis l'emplacement du script jusqu'à trouver .git
  local d
  d="$( cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P )"
  while [[ "$d" != "/" && ! -d "$d/.git" ]]; do
    d="$(dirname "$d")"
  done
  [[ -d "$d/.git" ]] && { echo "$d"; return; }
  echo ""  # échec
}

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(resolve_repo_root)}"
[[ -n "$REPO_ROOT" && -d "$REPO_ROOT" ]] || { echo "[ERR] Repo root introuvable"; exit 1; }
cd "$REPO_ROOT"

# --------- Paramètres par défaut ---------
: "${KUSTOMIZE_VERSION:=5.4.2}"
: "${KUBECONFORM_VERSION:=0.6.7}"
: "${WORKDIR:=$(pwd)}"
: "${CHECK_WHOAMI:=1}"
: "${CHECK_INGRESS_LAB:=1}"

# --------- Fonctions utilitaires ---------
log()   { printf "\n\033[1;34m[CI]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[WARN]\033[0m %s\n" "$*\n"; }
fail()  { printf "\033[1;31m[ERR]\033[0m %s\n" "$*\n"; exit 1; }

# Vérifie si une commande est disponible
need_cmd() { command -v "$1" >/dev/null 2>&1; }

# --------- Install kustomize ---------
install_kustomize() {
  if need_cmd kustomize; then
    log "kustomize déjà présent: $(kustomize version 2>/dev/null || echo '?')"
    return 0
  fi
  log "Installation de kustomize v${KUSTOMIZE_VERSION}..."
  # Récupère l’archive adaptée à l’OS/archi
  OS=$(uname | tr '[:upper:]' '[:lower:]')
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64|amd64) ARCH=amd64 ;;
    arm64|aarch64) ARCH=arm64 ;;
    *) warn "Arch inconnue ($ARCH), fallback amd64"; ARCH=amd64 ;;
  esac
  URL="https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_${OS}_${ARCH}.tar.gz"
  curl -fsSL "$URL" -o /tmp/kustomize.tgz
  tar -xzf /tmp/kustomize.tgz -C /tmp kustomize
  sudo mv /tmp/kustomize /usr/local/bin/kustomize
  sudo chmod +x /usr/local/bin/kustomize
  kustomize version
}

# --------- Install kubeconform ---------
install_kubeconform() {
  if need_cmd kubeconform; then
    log "kubeconform déjà présent: $(kubeconform -v 2>/dev/null || echo '?')"
    return 0
  fi
  log "Installation de kubeconform v${KUBECONFORM_VERSION}..."
  OS=$(uname | tr '[:upper:]' '[:lower:]')
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64|amd64) ARCH=amd64 ;;
    arm64|aarch64) ARCH=arm64 ;;
    *) warn "Arch inconnue ($ARCH), fallback amd64"; ARCH=amd64 ;;
  esac
  URL="https://github.com/yannh/kubeconform/releases/download/v${KUBECONFORM_VERSION}/kubeconform-${OS}-${ARCH}.tar.gz"
  curl -fsSL "$URL" -o /tmp/kubeconform.tgz
  tar -xzf /tmp/kubeconform.tgz -C /tmp kubeconform
  sudo mv /tmp/kubeconform /usr/local/bin/kubeconform
  sudo chmod +x /usr/local/bin/kubeconform
  kubeconform -v
}

# --------- Validation générique ---------
validate_kustomize_dir() {
  local path="$1"   # ex: apps/whoami
  local out="$2"    # ex: /tmp/whoami.yaml

  if [[ ! -d "$path" ]]; then
    warn "$path introuvable (skip)."
    return 0
  fi

  log "🔍 Build kustomize: $path"
  kustomize build "$path" | tee "$out" >/dev/null

  log "✅ kubeconform sur $path"
  kubeconform -strict -ignore-missing-schemas -summary <"$out"
}

# --------- Main ---------
main() {
  cd "$WORKDIR"

  # S’assure que les binaires sont dispos
  install_kustomize
  install_kubeconform

  local failures=0

  # Validation apps/whoami
  if [[ "${CHECK_WHOAMI}" == "1" ]]; then
    validate_kustomize_dir "apps/whoami" "/tmp/whoami.yaml" || failures=$((failures+1))
  else
    warn "Validation whoami désactivée (CHECK_WHOAMI=0)."
  fi

  # Validation ingress-nginx overlay lab
  if [[ "${CHECK_INGRESS_LAB}" == "1" ]]; then
    validate_kustomize_dir "apps/ingress-nginx/overlays/lab" "/tmp/ingress.yaml" || failures=$((failures+1))
  else
    warn "Validation ingress-nginx/lab désactivée (CHECK_INGRESS_LAB=0)."
  fi

  # Bilan final
  if (( failures > 0 )); then
    fail "Validations en échec: ${failures}"
  fi

  log "🎉 Toutes les validations sont passées."
}

main "$@"
