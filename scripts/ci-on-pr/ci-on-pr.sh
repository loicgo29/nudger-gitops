#!/usr/bin/env bash
# scripts/ci-on-pr.sh
# Valide les manifests Kustomize avec kubeconform, comme dans .github/workflows/ci-on-pr.yml

set -euo pipefail

# -------- Paramètres (override via env) --------
: "${KUSTOMIZE_VERSION:=5.4.2}"
: "${KUBECONFORM_VERSION:=0.6.7}"
: "${WORKDIR:=$(pwd)}"

# Active/désactive des blocs (utile si tu veux ne valider qu’une cible)
: "${CHECK_WHOAMI:=1}"
: "${CHECK_INGRESS_LAB:=1}"

# -------- Utils --------
log() { printf "\n\033[1;34m[CI]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[WARN]\033[0m %s\n" "$*\n"; }
fail() { printf "\033[1;31m[ERR]\033[0m %s\n" "$*\n"; exit 1; }

cleanup() {
  rm -f /tmp/whoami.yaml /tmp/ingress.yaml
}
trap cleanup EXIT

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || return 1
}

# -------- Install kustomize (si absent) --------
install_kustomize() {
  if need_cmd kustomize; then
    log "kustomize déjà présent: $(kustomize version 2>/dev/null || echo '?')"
    return 0
  fi
  log "Installation de kustomize v${KUSTOMIZE_VERSION}…"
  # action équivalente à imranismail/setup-kustomize@v4
  OS=$(uname | tr '[:upper:]' '[:lower:]')
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64|amd64) ARCH=amd64 ;;
    arm64|aarch64) ARCH=arm64 ;;
    *) warn "Arch non reconnue ($ARCH), tentative amd64"; ARCH=amd64 ;;
  esac
  URL="https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_${OS}_${ARCH}.tar.gz"
  curl -fsSL "$URL" -o /tmp/kustomize.tgz
  tar -xzf /tmp/kustomize.tgz -C /tmp kustomize
  sudo mv /tmp/kustomize /usr/local/bin/kustomize
  sudo chmod +x /usr/local/bin/kustomize
  kustomize version
}

# -------- Install kubeconform (si absent) --------
install_kubeconform() {
  if need_cmd kubeconform; then
    log "kubeconform déjà présent: $(kubeconform -v 2>/dev/null || echo '?')"
    return 0
  fi
  log "Installation de kubeconform v${KUBECONFORM_VERSION}…"
  OS=$(uname | tr '[:upper:]' '[:lower:]')
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64|amd64) ARCH=amd64 ;;
    arm64|aarch64) ARCH=arm64 ;;
    *) warn "Arch non reconnue ($ARCH), tentative amd64"; ARCH=amd64 ;;
  esac
  URL="https://github.com/yannh/kubeconform/releases/download/v${KUBECONFORM_VERSION}/kubeconform-${OS}-${ARCH}.tar.gz"
  curl -fsSL "$URL" -o /tmp/kubeconform.tgz
  tar -xzf /tmp/kubeconform.tgz -C /tmp kubeconform
  sudo mv /tmp/kubeconform /usr/local/bin/kubeconform
  sudo chmod +x /usr/local/bin/kubeconform
  kubeconform -v
}

# -------- Validation générique --------
validate_kustomize_dir() {
  local path="$1"
  local out="$2"

  if [[ ! -d "$path" ]]; then
    warn "$path introuvable (skip)."
    return 0
  fi

  log "🔍 Build kustomize: $path"
  kustomize build "$path" | tee "$out" >/dev/null

  log "✅ kubeconform sur $path"
  # aligné avec le workflow: strict + ignore-missing-schemas + summary
  kubeconform -strict -ignore-missing-schemas -summary <"$out"
}

# -------- Main --------
main() {
  cd "$WORKDIR"
  cd ../..

  install_kustomize
  install_kubeconform

  local failures=0

  if [[ "${CHECK_WHOAMI}" == "1" ]]; then
    validate_kustomize_dir "apps/whoami" "/tmp/whoami.yaml" || failures=$((failures+1))
  else
    warn "Validation whoami désactivée (CHECK_WHOAMI=0)."
  fi

  if [[ "${CHECK_INGRESS_LAB}" == "1" ]]; then
    validate_kustomize_dir "apps/ingress-nginx/overlays/lab" "/tmp/ingress.yaml" || failures=$((failures+1))
  else
    warn "Validation ingress-nginx/lab désactivée (CHECK_INGRESS_LAB=0)."
  fi

  if (( failures > 0 )); then
    fail "Validations en échec: ${failures}"
  fi

  log "🎉 Toutes les validations sont passées."
}

main "$@"
