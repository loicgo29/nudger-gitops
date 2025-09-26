#!/usr/bin/env bash
set -euo pipefail

NAMESPACES=("ns-open4goods-integration" "ns-open4goods-recette")

echo "🧹 Reset complet de XWiki et MariaDB/MySQL sur namespaces: ${NAMESPACES[*]}"
echo "⚠️ ATTENTION : les PVC seront supprimés → perte de données !"
echo

for ns in "${NAMESPACES[@]}"; do
  echo "🗑️  Deleting StatefulSets (XWiki + MariaDB)"
  kubectl -n "$ns" delete statefulset xwiki --ignore-not-found --cascade=orphan || true
  kubectl -n "$ns" delete statefulset xwiki-mariadb --ignore-not-found --cascade=orphan || true
  kubectl -n "$ns" delete statefulset mysql-xwiki --ignore-not-found --cascade=orphan || true
  echo "----------------------------------------------------"
  echo "➡️  Namespace: $ns"
  echo "----------------------------------------------------"

  echo "🩹 Removing finalizers"
  for res in $(kubectl -n "$ns" get helmrelease,sts,pods,pvc -o name 2>/dev/null || true); do
    kubectl -n "$ns" patch "$res" --type=merge -p '{"metadata":{"finalizers":[]}}' || true
  done

  echo "🗑️  Deleting PVCs"
  for pvc in $(kubectl -n "$ns" get pvc -o name | grep -E 'xwiki|mariadb|mysql' || true); do
    kubectl -n "$ns" delete "$pvc" --wait=false || true
  done

  echo "🗑️  Deleting ConfigMaps"
  for cm in $(kubectl -n "$ns" get cm -o name | grep -E 'xwiki|mariadb|mysql' || true); do
    kubectl -n "$ns" delete "$cm" || true
  done

  echo "🗑️  Deleting Secrets"
  for sec in $(kubectl -n "$ns" get secret -o name | grep -E 'xwiki|mariadb|mysql' || true); do
    kubectl -n "$ns" delete "$sec" || true
  done

  echo "🗑️  Deleting HelmReleases (si présents)"
  kubectl -n "$ns" delete helmrelease xwiki --ignore-not-found || true
  kubectl -n "$ns" delete helmrelease mysql-xwiki --ignore-not-found || true

  echo "🗑️  Deleting StatefulSet (force MySQL bloqué)"
  kubectl -n "$ns" delete statefulset mysql-xwiki --ignore-not-found --cascade=orphan || true

  echo "✅ Namespace $ns clean."
  echo
done

echo "----------------------------------------------------"
echo "➡️  Nettoyage FluxSystem (HelmCharts/Kustomizations)"
echo "----------------------------------------------------"

# Supprimer les HelmCharts liés à XWiki et MySQL
for hc in $(kubectl -n flux-system get helmcharts.source.toolkit.fluxcd.io -o name 2>/dev/null | grep -Ei 'xwiki|mysql' || true); do
  kubectl -n flux-system delete "$hc" --ignore-not-found || true
done

# Supprimer les Kustomizations liées à XWiki (si elles existent encore)
kubectl -n flux-system delete kustomization xwiki-integration xwiki-recette --ignore-not-found || true
kubectl -n flux-system delete kustomization mysql-integration mysql-recette --ignore-not-found || true
echo "----------------------------------------------------"
echo "🔎 Vérification post-reset"
echo "----------------------------------------------------"
kubectl get pvc,cm,secret,helmrelease,sts -A | grep -Ei 'xwiki|mysql' || echo "🟢 Plus aucune ressource XWiki/MySQL détectée"

echo "🎉 Reset XWiki + MySQL terminé."
