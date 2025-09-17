#!/usr/bin/env bash
# Smoke test namespaces + PSA + Kyverno (mutation RO rootfs)
# Rejouable, verbeux, avec PASS/FAIL et code de retour != 0 si échec.
set -euo pipefail

NS_PROD="${NS_PROD:-open4goods-prod}"
NS_INT="${NS_INT:-open4goods-integration}"
TIMEOUT_READY="${TIMEOUT_READY:-90s}"
TIMEOUT_INIT="${TIMEOUT_INIT:-30s}"
CLEANUP="${CLEANUP:-false}"   # true pour supprimer à la fin

# ---------------------------------------------------------------------------

bold()  { printf "\e[1m%s\e[0m\n" "$*"; }
info()  { printf "ℹ️  %s\n" "$*"; }
ok()    { printf "✅ %s\n" "$*"; }
warn()  { printf "⚠️  %s\n" "$*"; }
fail()  { printf "❌ %s\n" "$*"; exit 1; }

need()  { command -v "$1" >/dev/null 2>&1 || fail "binaire manquant: $1"; }

# ---------------------------------------------------------------------------

need kubectl

bold "Smoke test namespaces / PSA / Kyverno"
info "Namespaces: prod=${NS_PROD}, int=${NS_INT}"

# 0) Pré-checks
kubectl get ns "${NS_PROD}" >/dev/null || fail "namespace ${NS_PROD} introuvable"
kubectl get ns "${NS_INT}"  >/dev/null || fail "namespace ${NS_INT} introuvable"

# Labels PSA sur prod (idempotent)
kubectl label ns "${NS_PROD}" \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/audit=restricted \
  --overwrite >/dev/null
ok "PSA en 'restricted' sur ${NS_PROD}"

# Détecter Kyverno (pour la mutation RO)
HAS_KYVERNO=false
if kubectl get deploy -n kyverno kyverno-admission-controller >/dev/null 2>&1; then
  HAS_KYVERNO=true
  ok "Kyverno détecté (mutation test activé)"
else
  warn "Kyverno non détecté → test de mutation RO sera SKIPPED"
fi

# ---------------------------------------------------------------------------
# 1) PSA: un pod volontairement non conforme en PROD doit être REFUSÉ
bold "[1/3] PSA deny en prod (pod non conforme)"

set +e
kubectl -n "${NS_PROD}" apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: smoke-psa-bad
spec:
  containers:
  - name: web
    image: nginx:1.27-alpine
    # aucune securityContext => PSA 'restricted' doit refuser
EOF
RC=$?
set -e

if [[ $RC -eq 0 ]]; then
  # si par hasard créé, on lit les events et on échoue
  kubectl -n "${NS_PROD}" describe pod smoke-psa-bad || true
  fail "PSA n'a pas refusé smoke-psa-bad (attendu: Forbidden)."
else
  ok "PSA a correctement refusé le pod non conforme (Forbidden attendu)."
fi

# ---------------------------------------------------------------------------
# 2) KYVERNO: mutation RO rootfs en PROD (si présent)
bold "[2/3] Mutation RO rootfs par Kyverno (prod)"
if [[ "${HAS_KYVERNO}" == "true" ]]; then
  kubectl -n "${NS_PROD}" apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: smoke-kyv-mut
spec:
  securityContext:
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: c
    image: busybox:1.36
    command: ["sh","-c","sleep 3600"]
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      runAsNonRoot: true
      readOnlyRootFilesystem: false   # <-- volontairement faux : Kyverno doit le muter à true
EOF

  kubectl -n "${NS_PROD}" wait pod/smoke-kyv-mut --for=condition=Initialized --timeout="${TIMEOUT_INIT}" >/dev/null || true

  RO=$(kubectl -n "${NS_PROD}" get pod smoke-kyv-mut -o jsonpath='{.spec.containers[0].securityContext.readOnlyRootFilesystem}' 2>/dev/null || echo "")
  if [[ "${RO}" == "true" ]]; then
    ok "Kyverno a bien muté readOnlyRootFilesystem → true"
  else
    kubectl -n "${NS_PROD}" get pod smoke-kyv-mut -o yaml | sed -n '1,160p' || true
    fail "Kyverno n'a PAS muté à true (policy non appliquée/selector ?)"
  fi
else
  warn "SKIP mutation: Kyverno absent"
fi
# ---------------------------------------------------------------------------
# 3) INT: un pod simple doit passer en Running
bold "[3/3] Pod simple en integration (baseline)"

kubectl -n "${NS_INT}" apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: smoke-int-ok
spec:
  containers:
  - name: web
    image: nginxinc/nginx-unprivileged:1.27-alpine
    command: ["sh","-c","sleep 3600"]
EOF

kubectl -n "${NS_INT}" wait pod/smoke-int-ok --for=condition=Ready --timeout="${TIMEOUT_READY}" >/dev/null \
  || fail "smoke-int-ok n'est pas Ready (problème cluster ou image)."
ok "integration: pod Ready"

# ---------------------------------------------------------------------------
# Récapitulatif
echo
bold "=== RÉSULTAT ==="
ok "1) PSA deny en prod : OK"
if [[ "${HAS_KYVERNO}" == "true" ]]; then
  ok "2) Mutation RO par Kyverno : OK"
else
  warn "2) Mutation RO par Kyverno : SKIPPED (Kyverno absent)"
fi
ok "3) Pod en integration : OK"

# ---------------------------------------------------------------------------
# Cleanup optionnel
if [[ "${CLEANUP}" == "true" ]]; then
  info "Nettoyage…"
  kubectl -n "${NS_PROD}" delete pod smoke-psa-bad --ignore-not-found
  kubectl -n "${NS_PROD}" delete pod smoke-kyv-mut --ignore-not-found
  kubectl -n "${NS_INT}"  delete pod smoke-int-ok --ignore-not-found
  ok "Nettoyé"
fi
