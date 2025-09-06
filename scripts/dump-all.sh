#!/usr/bin/env bash
set -euo pipefail

# --- Réglages rapides ---------------------------------------------------------
OUT_ROOT="${OUT_ROOT:-./install-dump}"
NS_FLUX="${NS_FLUX:-flux-system}"
NS_ING="${NS_ING:-ingress-nginx}"
NS_OBS="${NS_OBS:-observability}"
NS_LONGHORN="${NS_LONGHORN:-longhorn-system}"
NS_CERT="${NS_CERT:-cert-manager}"
NS_LOGGING="${NS_LOGGING:-logging}"
NS_WHOAMI="${NS_WHOAMI:-whoami}"

NODE_IP="${NODE_IP:-}"         # ex: export NODE_IP=91.98.16.184 avant d'exécuter (facultatif)
TEST_HOST_HTTP="${TEST_HOST_HTTP:-whoami.91-98-16-184.nip.io}"  # adapte si besoin
NODEPORT_HTTP="${NODEPORT_HTTP:-30080}"
NODEPORT_HTTPS="${NODEPORT_HTTPS:-30443}"

# --- Préparation dossier ------------------------------------------------------
TS="$(date +%F-%H%M%S)"
OUT="${OUT_ROOT}/${TS}"
mkdir -p "${OUT}"/{sys,iptables,flux,helm,ingress,cert,network,longhorn,logging,whoami}

echo "==> Dump dans: ${OUT}"

# --- Infos système & versions -------------------------------------------------
{
  echo "# Versions"
  uname -a || true
  cat /etc/os-release || true
  which kubectl && kubectl version --short || true
  which flux && flux --version || true
  which helm && helm version || true
  which crictl && crictl --version || true
} > "${OUT}/sys/versions.txt" 2>&1

# --- Cluster & nodes ----------------------------------------------------------
kubectl cluster-info > "${OUT}/sys/cluster-info.txt" 2>&1 || true
kubectl get nodes -o wide > "${OUT}/sys/nodes.txt" 2>&1 || true
kubectl get ns > "${OUT}/sys/namespaces.txt" 2>&1 || true

# --- Flux ---------------------------------------------------------------------
{
  echo "## sources"
  flux get sources git -n "${NS_FLUX}" || true
  flux get sources helm -n "${NS_FLUX}" || true

  echo -e "\n## kustomizations"
  flux get kustomizations -A || true

  echo -e "\n## helmreleases"
  flux get helmreleases -A || true
} > "${OUT}/flux/overview.txt" 2>&1

kubectl -n "${NS_FLUX}" get gitrepository -o yaml > "${OUT}/flux/gitrepositories.yaml" 2>&1 || true
kubectl -n "${NS_FLUX}" get kustomization -o yaml > "${OUT}/flux/kustomizations.yaml" 2>&1 || true
kubectl -n "${NS_FLUX}" get helmrelease -A -o yaml > "${OUT}/flux/helmreleases.yaml" 2>&1 || true

kubectl -n "${NS_FLUX}" logs deploy/source-controller --tail=400 > "${OUT}/flux/source-controller.log" 2>&1 || true
kubectl -n "${NS_FLUX}" logs deploy/helm-controller --tail=400 > "${OUT}/flux/helm-controller.log" 2>&1 || true
kubectl -n "${NS_FLUX}" logs deploy/kustomize-controller --tail=400 > "${OUT}/flux/kustomize-controller.log" 2>&1 || true

# --- Helm global --------------------------------------------------------------
helm list -A > "${OUT}/helm/helm-list.txt" 2>&1 || true

# --- Ingress / NGINX ----------------------------------------------------------
kubectl -n "${NS_ING}" get all -o wide > "${OUT}/ingress/resources.txt" 2>&1 || true
kubectl -n "${NS_ING}" get svc ingress-nginx-controller -o yaml > "${OUT}/ingress/svc-controller.yaml" 2>&1 || true
kubectl -n "${NS_ING}" get deploy ingress-nginx-controller -o yaml > "${OUT}/ingress/deploy-controller.yaml" 2>&1 || true
kubectl -n "${NS_ING}" get events --sort-by=.lastTimestamp > "${OUT}/ingress/events.txt" 2>&1 || true
kubectl -n "${NS_ING}" logs deploy/ingress-nginx-controller --tail=400 > "${OUT}/ingress/controller.log" 2>&1 || true

# --- Whoami (exemple d’app) ---------------------------------------------------
kubectl -n "${NS_WHOAMI}" get all -o wide > "${OUT}/whoami/resources.txt" 2>&1 || true
kubectl -n "${NS_WHOAMI}" get ingress -o yaml > "${OUT}/whoami/ingresses.yaml" 2>&1 || true
kubectl -n "${NS_WHOAMI}" describe ingress whoami > "${OUT}/whoami/ingress-whoami.describe.txt" 2>&1 || true

# --- Cert-Manager -------------------------------------------------------------
kubectl -n "${NS_CERT}" get all > "${OUT}/cert/resources.txt" 2>&1 || true
kubectl -n "${NS_CERT}" get clusterissuer,issuer -o yaml > "${OUT}/cert/issuers.yaml" 2>&1 || true
kubectl -n "${NS_CERT}" get certificate,order,challenge -A -o wide > "${OUT}/cert/cert-order-challenge.txt" 2>&1 || true
kubectl -n "${NS_CERT}" logs deploy/cert-manager --tail=400 > "${OUT}/cert/cert-manager.log" 2>&1 || true

# --- Observability (Grafana/Prometheus/Loki si présents) ----------------------
kubectl -n "${NS_OBS}" get all -o wide > "${OUT}/logging/observability.txt" 2>&1 || true
kubectl -n "${NS_LOGGING}" get all -o wide > "${OUT}/logging/logging-ns.txt" 2>&1 || true
kubectl -n "${NS_LOGGING}" logs statefulset/loki --tail=200 > "${OUT}/logging/loki.log" 2>&1 || true

# --- Longhorn -----------------------------------------------------------------
kubectl -n "${NS_LONGHORN}" get all -o wide > "${OUT}/longhorn/resources.txt" 2>&1 || true
kubectl get sc -o yaml > "${OUT}/longhorn/storageclasses.yaml" 2>&1 || true
kubectl -n "${NS_LONGHORN}" get ingress -o yaml > "${OUT}/longhorn/ingresses.yaml" 2>&1 || true

# --- iptables / kube-proxy / CNI ---------------------------------------------
# iptables NAT + filter (lisibles & sauvegardes brutes)
sudo iptables -t nat -S  > "${OUT}/iptables/nat-S.txt" 2>&1 || true
sudo iptables -S         > "${OUT}/iptables/filter-S.txt" 2>&1 || true
sudo iptables-save       > "${OUT}/iptables/iptables-save.rules" 2>&1 || true
sudo iptables-save -t nat > "${OUT}/iptables/iptables-nat.rules" 2>&1 || true

# Chaînes spécifiques NodePort
{
  echo "### KUBE-NODEPORTS (résumé)"
  sudo iptables -t nat -L KUBE-NODEPORTS -n -v || true
  echo
  echo "### Détail des chains cibles depuis KUBE-NODEPORTS"
  for CH in $(sudo iptables -t nat -S KUBE-NODEPORTS 2>/dev/null | awk '/KUBE-EXT-/{print $3}'); do
    echo "=== $CH ==="
    sudo iptables -t nat -S "$CH" || true
    echo
  done
} > "${OUT}/iptables/nodeports.txt" 2>&1

# kube-proxy config (utile pour savoir iptables/ipvs)
kubectl -n kube-system get cm kube-proxy -o yaml > "${OUT}/network/kube-proxy-cm.yaml" 2>&1 || true

# CNI (flannel)
kubectl -n kube-flannel get cm kube-flannel-cfg -o yaml > "${OUT}/network/kube-flannel-cfg.yaml" 2>&1 || true
ip -o -f inet addr show cni0 > "${OUT}/network/cni0.addr.txt" 2>&1 || true
ip route show table main > "${OUT}/network/routes.txt" 2>&1 || true

# --- Endpoints & Services clés ------------------------------------------------
kubectl -n "${NS_ING}" get svc ingress-nginx-controller -o wide > "${OUT}/ingress/svc-controller.wide.txt" 2>&1 || true
kubectl -n "${NS_ING}" get endpoints ingress-nginx-controller -o wide > "${OUT}/ingress/ep-controller.txt" 2>&1 || true

# --- Tests NodePort HTTP/HTTPS (si NODE_IP fourni) ----------------------------
if [[ -n "${NODE_IP}" ]]; then
  {
    echo "# Test HTTP NodePort"
    echo "curl -I http://${NODE_IP}:${NODEPORT_HTTP} -H 'Host: ${TEST_HOST_HTTP}'"
    curl -I "http://${NODE_IP}:${NODEPORT_HTTP}" -H "Host: ${TEST_HOST_HTTP}" || true

    echo -e "\n# Test HTTPS NodePort (insecure)"
    echo "curl -kI https://${NODE_IP}:${NODEPORT_HTTPS} -H 'Host: ${TEST_HOST_HTTP}'"
    curl -kI "https://${NODE_IP}:${NODEPORT_HTTPS}" -H "Host: ${TEST_HOST_HTTP}" || true
  } > "${OUT}/ingress/nodeport-curl.txt" 2>&1
fi

# --- Events cluster récents ---------------------------------------------------
kubectl get events -A --sort-by=.lastTimestamp > "${OUT}/sys/events-all.txt" 2>&1 || true

# --- Résumé rapide ------------------------------------------------------------
{
  echo "== RÉSUMÉ =="
  echo "Dossier: ${OUT}"
  echo
  echo "Ingress:"
  kubectl -n "${NS_ING}" get svc ingress-nginx-controller -o wide || true
  echo
  echo "Whoami:"
  kubectl -n "${NS_WHOAMI}" get ingress whoami -o wide || true
  echo
  echo "Flux:"
  flux get kustomizations -A || true
  echo
  echo "NodePorts counters (iptables):"
  sudo iptables -t nat -L KUBE-NODEPORTS -n -v || true
} > "${OUT}/SUMMARY.txt" 2>&1

echo "✅ Dump terminé. Parcours conseillé :"
echo "  - ${OUT}/SUMMARY.txt"
echo "  - ${OUT}/ingress/nodeport-curl.txt (si NODE_IP défini)"
echo "  - ${OUT}/flux/*.log, ${OUT}/ingress/controller.log"
echo "  - ${OUT}/iptables/nodeports.txt, iptables-nat.rules"
