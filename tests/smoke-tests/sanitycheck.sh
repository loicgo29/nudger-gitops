#!/usr/bin/env bash
# sanitycheck.sh — Sanity check cluster (Flux, Longhorn, Loki/Promtail, Grafana, Ingress, Kyverno, CNI, cert-manager)
# Usage: ./smoke-tests/sanitycheck.sh [-q] [-t SECS] [-n LOKI_NS]
set -Eeuo pipefail

# ---------- CLI / Defaults ----------
QUIET=0
PF_TIMEOUT="${PF_TIMEOUT:-900}"
LOKI_NS="${LOKI_NS:-logging}"
PROMTAIL_NS="${PROMTAIL_NS:-logging}"
GRAFANA_NS="${GRAFANA_NS:-observability}"
ING_NS="${ING_NS:-ingress-nginx}"
WHO_NS="${WHO_NS:-whoami}"
KYV_NS="${KYV_NS:-kyverno}"

while getopts ":qt:n:" opt; do
  case "$opt" in
    q) QUIET=1 ;;
    t) PF_TIMEOUT="$OPTARG" ;;
    n) LOKI_NS="$OPTARG" ;;
    *) echo "Option inconnue: -$OPTARG" >&2; exit 2 ;;
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
    fail "binaire requis manquant: $1"; exit 3
  fi
}

has_resource() { # ns, group(kind), name
  local ns="$1" gk="$2" name="$3"
  kubectl -n "$ns" get "$gk" "$name" >/dev/null 2>&1
}

count_resources() { # ns, kind, labelSelector
  local ns="$1" kind="$2" sel="$3"
  kubectl -n "$ns" get "$kind" -l "$sel" --no-headers 2>/dev/null | wc -l | tr -d ' '
}

EXIT_CODE=0
trap '[[ $EXIT_CODE -eq 0 ]] || echo "→ code de sortie: $EXIT_CODE"' EXIT

need kubectl
command -v flux >/dev/null 2>&1 && FLUX=flux || FLUX=""
command -v jq   >/dev/null 2>&1 && JQ=jq   || JQ=""
command -v yq   >/dev/null 2>&1 && YQ=yq   || YQ=""

[[ -z "$FLUX" ]] && warn "flux CLI non trouvé (les vérifs Flux seront limitées)"

# ---------- 1) Control-plane ----------
hr "Control-plane"
kubectl get nodes -owide || { fail "kubectl get nodes KO"; EXIT_CODE=1; }
if kubectl -n kube-system get pods -l k8s-app=kube-dns >/dev/null 2>&1; then
  DNS_OK=$(kubectl -n kube-system get pods -l k8s-app=kube-dns -o jsonpath='{range .items[*]}{.status.phase}{" "}{end}' || true)
  [[ "$DNS_OK" =~ Running ]] && pass "CoreDNS Running" || { fail "CoreDNS pas Running: $DNS_OK"; EXIT_CODE=1; }
else
  warn "Label k8s-app=kube-dns introuvable; vérifie CoreDNS manuellement"
fi

# ---------- 2) CNI (Flannel) ----------
hr "CNI / Flannel"
kubectl -n kube-flannel get ds,pods -owide || { fail "Flannel introuvable"; EXIT_CODE=1; }
if [[ -f /run/flannel/subnet.env ]]; then pass "/run/flannel/subnet.env présent"; else warn "/run/flannel/subnet.env manquant (OK si tu n'es pas sur le noeud)"; fi

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
kubectl get sc || { fail "kubectl get sc KO"; EXIT_CODE=1; }
if [[ "$(kubectl get sc | awk '/\(default\)/' | wc -l | tr -d ' ')" == "1" ]]; then
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
  for _ in $(seq 1 $(( PF_TIMEOUT/5 ))); do
    READY="$(curl -s localhost:3100/ready || true)"
    [[ "$READY" == "ready" ]] && break
    sleep 5
  done
  kill "$PF" >/dev/null 2>&1 || true
  [[ "$READY" == "ready" ]] && pass "Loki /ready = ready" || { fail "Loki pas ready (dernier: $READY)"; EXIT_CODE=1; }
else
  fail "Service loki introuvable dans ns $LOKI_NS"; EXIT_CODE=1
fi

# ---------- 6) Promtail ----------
hr "Promtail"
# ---------- 6) Promtail ----------
hr "Promtail"
# 6.1 — Statut de l'HelmRelease (sans afficher le tableau flux)
HR_OK=0
HR_MSG=""
if has_resource "$PROMTAIL_NS" "helmrelease.helm.toolkit.fluxcd.io" "promtail"; then
  # Ne PAS faire: flux -n "$PROMTAIL_NS" get helmreleases promtail   # (ça imprime le tableau et le header NAME)
  HR_MSG="$(kubectl -n "$PROMTAIL_NS" get hr promtail -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}' 2>/dev/null || true)"
  if kubectl -n "$PROMTAIL_NS" get hr promtail -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q True; then
    HR_OK=1
  fi
  [[ -n "$HR_MSG" ]] && say "$HR_MSG"
fi

# 6.2 — Présence DS & Pods (sans bruit "No resources found")
PROMTAIL_DS_PRESENT=0
PROMTAIL_PODS=0
if kubectl -n "$PROMTAIL_NS" get ds promtail -o name >/dev/null 2>&1; then
  PROMTAIL_DS_PRESENT=1
  PROMTAIL_PODS="$(kubectl -n "$PROMTAIL_NS" get po -l app.kubernetes.io/name=promtail --no-headers 2>/dev/null | wc -l | tr -d ' ')"
fi

if (( PROMTAIL_DS_PRESENT == 1 )); then
  if (( PROMTAIL_PODS > 0 )); then
    pass "Promtail OK (pods: $PROMTAIL_PODS)"
    # Vérifie les 4xx/5xx seulement si pods
    if kubectl -n "$PROMTAIL_NS" logs -l app.kubernetes.io/name=promtail --tail=400 2>/dev/null | egrep -E ' (4[0-9]{2}|5[0-9]{2}) ' >/dev/null; then
      fail "Promtail rapporte des 4xx/5xx vers Loki"
      kubectl -n "$PROMTAIL_NS" logs -l app.kubernetes.io/name=promtail --tail=200 | egrep -E ' (4[0-9]{2}|5[0-9]{2}) ' || true
      EXIT_CODE=1
    else
      pass "Promtail: pas de 4xx/5xx récents"
    fi
  else
    warn "DaemonSet promtail présent mais aucun pod (en attente/CrashLoop ?)"
    kubectl -n "$PROMTAIL_NS" describe ds promtail | sed -n '/Events/,$p' || true
    EXIT_CODE=1
  fi
else
  # Ni DS ni pods : ne pas échouer si l’HR est Ready (prune/disabled)
  if (( HR_OK == 1 )); then
    warn "HelmRelease promtail présent mais pas d’objets déployés (OK si désactivé ou pruné)"
  else
    warn "Promtail non trouvé dans $PROMTAIL_NS (OK si non installé sur cet env)"
  fi
fi
if (( PROMTAIL_DS_PRESENT == 1 )); then
  if (( PROMTAIL_PODS > 0 )); then
    pass "Promtail présent (pods: $PROMTAIL_PODS)"
    # 6.3 — Vérifie 4xx/5xx vers Loki uniquement si pods
    if kubectl -n "$PROMTAIL_NS" logs -l app.kubernetes.io/name=promtail --tail=400 2>/dev/null | egrep -E ' (4[0-9]{2}|5[0-9]{2}) ' >/dev/null; then
      fail "Promtail rapporte des 4xx/5xx vers Loki"
      kubectl -n "$PROMTAIL_NS" logs -l app.kubernetes.io/name=promtail --tail=200 | egrep -E ' (4[0-9]{2}|5[0-9]{2}) ' || true
      EXIT_CODE=1
    else
      pass "Promtail: pas de 4xx/5xx récents"
    fi
  else
    warn "DaemonSet promtail présent mais aucun pod (en attente/CrashLoop ?)"
    kubectl -n "$PROMTAIL_NS" describe ds promtail | sed -n '/Events/,$p' || true
    EXIT_CODE=1
  fi
else
  # Ni DS ni pods -> ne pas échouer si l’HelmRelease est “Ready”
  if (( HR_OK == 1 )); then
    warn "HelmRelease promtail présent mais pas d’objets déployés (OK si désactivé ou pruné)"
  else
    warn "Promtail non trouvé dans $PROMTAIL_NS (OK si tu ne l’installes pas sur cet env)"
  fi
fi

# ---------- 7) Grafana ----------
hr "Grafana"
if kubectl -n "$GRAFANA_NS" get pods -l app.kubernetes.io/name=grafana >/dev/null 2>&1; then
  kubectl -n "$GRAFANA_NS" get pods -l app.kubernetes.io/name=grafana
  if kubectl -n "$GRAFANA_NS" get pvc grafana >/dev/null 2>&1; then
    SC="$(kubectl -n "$GRAFANA_NS" get pvc grafana -o jsonpath='{.spec.storageClassName}')"
    PH="$(kubectl -n "$GRAFANA_NS" get pvc grafana -o jsonpath='{.status.phase}')"
    SZ="$(kubectl -n "$GRAFANA_NS" get pvc grafana -o jsonpath='{.status.capacity.storage}')"
    [[ "$PH" == "Bound" ]] && pass "PVC grafana: $SC $PH $SZ" || warn "PVC grafana non-Bound: $PH"
  else
    warn "PVC grafana non trouvée (OK si persistence désactivée)"
  fi
else
  warn "Grafana pods non trouvés (ns $GRAFANA_NS)"
fi

# ---------- 8) Ingress-NGINX ----------
hr "Ingress-NGINX"
kubectl -n "$ING_NS" get ds,svc || { fail "Ingress NGINX KO"; EXIT_CODE=1; }
# Si c'est un DaemonSet, ne tente pas de lire les logs du Deployment
if kubectl -n "$ING_NS" get deploy ingress-nginx-controller >/dev/null 2>&1; then
  if kubectl -n "$ING_NS" logs deploy/ingress-nginx-controller --tail=200 | egrep -i "error|crit" >/dev/null; then
    warn "Erreurs dans les logs du controller"
    kubectl -n "$ING_NS" logs deploy/ingress-nginx-controller --tail=100 | egrep -i "error|crit" || true
  else
    pass "Ingress-NGINX logs OK"
  fi
else
  say "Controller déployé en DaemonSet (attendu) — skip logs deploy"
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

# ---------- 10) Kyverno smoke pod (indice) ----------
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
