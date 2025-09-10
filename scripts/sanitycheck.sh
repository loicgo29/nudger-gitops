#!/usr/bin/env bash
# k8s_sanity.sh — Sanity check cluster (Flux, Longhorn, Loki/Promtail, Grafana, Ingress, Kyverno, CNI, cert-manager)
# Usage: ./k8s_sanity.sh [-q] [-t SECS] [-n LOKI_NS]
set -euo pipefail

# ---------- CLI ----------
QUIET=0
PF_TIMEOUT="${PF_TIMEOUT:-900}"
LOKI_NS="${LOKI_NS:-logging}"
PROMTAIL_NS="${PROMTAIL_NS:-logging}"
GRAFANA_NS="${GRAFANA_NS:-observability}"
ING_NS="${ING_NS:-ingress-nginx}"
WHO_NS="${WHO_NS:-whoami}"
KYV_NS="${KYV_NS:-kyverno}"

while getopts ":qt:n:" opt; do
  case $opt in
    q) QUIET=1 ;;
    t) PF_TIMEOUT="$OPTARG" ;;
    n) LOKI_NS="$OPTARG" ;;
    \?) echo "Opt inconnue -$OPTARG" >&2; exit 2 ;;
  esac
done

# ---------- Utils ----------
RED=$'\e[31m'; GRN=$'\e[32m'; YEL=$'\e[33m'; BLU=$'\e[34m'; RST=$'\e[0m'
say()   { [[ $QUIET -eq 1 ]] && return 0; echo -e "$@"; }
pass()  { echo -e "✅ ${GRN}$*${RST}"; }
warn()  { echo -e "⚠️  ${YEL}$*${RST}"; }
fail()  { echo -e "❌ ${RED}$*${RST}"; }
hr()    { [[ $QUIET -eq 1 ]] && return 0; echo -e "${BLU}── $* ─────────────────────────────${RST}"; }

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "binaire requis manquant: $1"
    exit 3
  fi
}

need kubectl
if command -v jq >/dev/null 2>&1; then JQ=jq; else JQ=""; warn "jq non trouvé (OK mais sortie moins riche)"; fi
if command -v yq >/dev/null 2>&1; then YQ=yq; else YQ=""; fi
if command -v flux >/dev/null 2>&1; then FLUX=flux; else FLUX=""; warn "flux CLI non trouvé (certaines vérifs seront sautées)"; fi

EXIT_CODE=0
trap '[[ $EXIT_CODE -eq 0 ]] || echo "→ code de sortie: $EXIT_CODE"' EXIT

# ---------- 1) Control-plane ----------
hr "Control-plane"
kubectl get nodes -owide || { fail "kubectl get nodes KO"; EXIT_CODE=1; }
if kubectl -n kube-system get pods -l k8s-app=kube-dns >/dev/null 2>&1; then
  DNS_OK=$(kubectl -n kube-system get pods -l k8s-app=kube-dns -o jsonpath='{range .items[*]}{.status.phase}{" "}{end}' || true)
  if [[ "$DNS_OK" =~ Running ]]; then pass "CoreDNS Running"; else fail "CoreDNS pas Running: $DNS_OK"; EXIT_CODE=1; fi
else
  # clusters récents: label peut varier
  warn "Label k8s-app=kube-dns introuvable; vérifie manuellement CoreDNS"
fi

# ---------- 2) CNI (Flannel) ----------
hr "CNI / Flannel"
kubectl -n kube-flannel get ds,pods -owide || { fail "Flannel introuvable"; EXIT_CODE=1; }
if [[ -f /run/flannel/subnet.env ]]; then pass "/run/flannel/subnet.env présent"; else warn "/run/flannel/subnet.env manquant sur cette machine (OK si tu n'es pas sur le noeud)"; fi

# ---------- 3) Storage (Longhorn) ----------
hr "Longhorn & StorageClasses"
if kubectl -n longhorn-system get pods >/dev/null 2>&1; then
  if kubectl -n longhorn-system get pods | grep -E 'CrashLoopBackOff|Error' >/dev/null; then
    fail "Pods Longhorn en erreur"; kubectl -n longhorn-system get pods; EXIT_CODE=1
  else
    pass "Pods Longhorn OK"
  fi
else
  warn "Namespace longhorn-system absent ?"
fi
kubectl get sc || { fail "get sc KO"; EXIT_CODE=1; }
if kubectl get sc | awk '/\(default\)/' | wc -l | grep -q '^1$'; then
  pass "1 StorageClass par défaut"
else
  warn "0 ou >1 StorageClass par défaut — unifie (attendu: longhorn)"
fi
if kubectl get pvc -A | grep -v NAMESPACE | grep -v Bound >/dev/null; then
  warn "PVC non-Bound détectées :"; kubectl get pvc -A | grep -v Bound || true
else
  pass "Toutes les PVC sont Bound"
fi

# ---------- 4) Flux ----------
hr "Flux Kustomizations & HelmReleases"
if [[ -n "$FLUX" ]]; then
  $FLUX -n flux-system get kustomizations || { fail "Flux KS KO"; EXIT_CODE=1; }
  $FLUX -n "$LOKI_NS" get helmreleases || warn "Pas de HR dans $LOKI_NS (OK si séparé)"
else
  warn "flux CLI absent — on saute ces checks"
fi

# ---------- 5) Loki readiness ----------
hr "Loki /ready"
if kubectl -n "$LOKI_NS" get svc loki >/dev/null 2>&1; then
  kubectl -n "$LOKI_NS" port-forward svc/loki 3100:3100 >/dev/null 2>&1 &
  PF=$!
  READY=""
  for i in $(seq 1 $(( PF_TIMEOUT/5 ))); do
    READY="$(curl -s localhost:3100/ready || true)"
    [[ "$READY" == "ready" ]] && break
    sleep 5
  done
  kill $PF >/dev/null 2>&1 || true
  if [[ "$READY" == "ready" ]]; then pass "Loki /ready = ready"; else fail "Loki pas ready (dernier: $READY)"; EXIT_CODE=1; fi
else
  fail "Service loki introuvable dans ns $LOKI_NS"; EXIT_CODE=1
fi

# ---------- 6) Promtail push errors ----------
hr "Promtail push"
if kubectl -n "$PROMTAIL_NS" get pods | grep -i promtail >/dev/null 2>&1; then
  # promtail peut être en DaemonSet: on lit tous les pods
  if kubectl -n "$PROMTAIL_NS" logs -l app.kubernetes.io/name=promtail --tail=200 2>/dev/null | egrep -i " (5..|4..) " >/dev/null; then
    fail "Promtail rapporte des 4xx/5xx vers Loki"; kubectl -n "$PROMTAIL_NS" logs -l app.kubernetes.io/name=promtail --tail=100 || true; EXIT_CODE=1
  else
    pass "Promtail: pas de 4xx/5xx récents"
  fi
else
  warn "Promtail non trouvé dans $PROMTAIL_NS (peut être normal si désactivé)"
fi

# ---------- 7) Grafana ----------
hr "Grafana"
if kubectl -n "$GRAFANA_NS" get pods -l app.kubernetes.io/name=grafana >/dev/null 2>&1; then
  kubectl -n "$GRAFANA_NS" get pods -l app.kubernetes.io/name=grafana
  # PVC facultative (tu peux avoir ephemeral); on n'échoue pas si absente
  if kubectl -n "$GRAFANA_NS" get pvc grafana >/dev/null 2>&1; then
    SC="$(kubectl -n "$GRAFANA_NS" get pvc grafana -o jsonpath='{.spec.storageClassName}')"
    PH="$(kubectl -n "$GRAFANA_NS" get pvc grafana -o jsonpath='{.status.phase}')"
    SZ="$(kubectl -n "$GRAFANA_NS" get pvc grafana -o jsonpath='{.status.capacity.storage}')"
    if [[ "$PH" == "Bound" ]]; then pass "PVC grafana: $SC $PH $SZ"; else warn "PVC grafana non-Bound: $PH"; fi
  else
    warn "PVC grafana non trouvée (OK si persistence désactivée)"
  fi
else
  warn "Grafana pods non trouvés (ns $GRAFANA_NS)"
fi

# ---------- 8) Ingress-NGINX ----------
hr "Ingress-NGINX"
kubectl -n "$ING_NS" get ds,svc || { fail "Ingress NGINX KO"; EXIT_CODE=1; }
# Pas de Deployment pour le controller si DaemonSet → ne considère pas l'erreur comme KO
if ! kubectl -n "$ING_NS" logs deploy/ingress-nginx-controller --tail=50 >/dev/null 2>&1; then
  say "Controller déployé en DaemonSet (attendu) — skip logs deploy"
else
  if kubectl -n "$ING_NS" logs deploy/ingress-nginx-controller --tail=200 | egrep -i "error|crit" >/dev/null; then
    warn "Erreurs dans les logs du controller"; kubectl -n "$ING_NS" logs deploy/ingress-nginx-controller --tail=100 | egrep -i "error|crit" || true
  else pass "Ingress-NGINX logs OK"; fi
fi

# ---------- 9) whoami probes ----------
hr "whoami"
if kubectl -n "$WHO_NS" get deploy whoami >/dev/null 2>&1; then
  DESCR="$(kubectl -n "$WHO_NS" describe deploy whoami | sed -n '/Liveness/,/Conditions/p' || true)"
  echo "$DESCR"
  if echo "$DESCR" | grep -qi "timeout=1s"; then
    warn "Probes whoami très strictes (timeout=1s) — recommande 2-3s et délais init plus longs"
  else
    pass "Probes whoami raisonnables"
  fi
else
  warn "whoami non trouvé (ns $WHO_NS)"
fi

# ---------- 10) Kyverno: smoke pod event hints ----------
hr "Kyverno smoke pod (si présent)"
if kubectl -n open4goods-prod get pod smoke-kyv-mut >/dev/null 2>&1; then
  kubectl -n open4goods-prod describe pod smoke-kyv-mut | sed -n '/Events/,$p' || true
  warn "Si tu imposes runAsNonRoot, n'utilise pas busybox root. Fixe runAsUser: 10001 ou exclue ce pod."
fi

# ---------- 11) cert-manager ----------
hr "cert-manager"
if kubectl -n cert-manager get pods >/dev/null 2>&1; then
  kubectl -n cert-manager get pods
else
  warn "Namespace cert-manager vide — OK si tu utilises uniquement des ClusterIssuers externes"
fi
kubectl get clusterissuers,issuers -A || true

# ---------- Résumé ----------
hr "Résumé"
if [[ $EXIT_CODE -eq 0 ]]; then
  pass "SANITY CHECK: OK"
else
  fail "SANITY CHECK: KO (voir messages ci-dessus)"
fi
exit $EXIT_CODE
