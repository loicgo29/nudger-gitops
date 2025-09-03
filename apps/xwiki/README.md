
# Open4Goods — Spécification synthétique (XWiki + MySQL → Kubernetes via Ansible)

> **But** : migrer le Docker Compose (XWiki + MySQL) en **Kubernetes** avec **Longhorn**, **sécurité par défaut**, **observabilité**, **sauvegardes**, et **GitOps**. Approche **Ansible-first** (rôles + templates), **scalabilité limitée** (XWiki mono‑réplica), **résilience prioritaire**.

---

## 1) Architecture générale
- **Cible initiale** : 1 nœud (master1). ⚠️ Tolérance de panne limitée jusqu’à ajout de nœuds.
- **Applications** : 
  - **XWiki 17.3.0-mysql-tomcat** — 1 replica, PVC RWO `xwiki-data` (ext4).
  - **MySQL** — StatefulSet, PVC RWO 50 Gi `mysql-data` (xfs), **SC `longhorn-db`**.
- **Exposition** : un **IngressController NGINX** (L7), **cert-manager** (ACME HTTP‑01), **external-dns** (OVH → Cloudflare possible).
- **Namespaces** : `open4goods-prod`, `open4goods-staging`, `ingress-nginx`, `cert-manager`, `external-dns`, `observability`.

**Alerte** : le tag d’image **`mysql:9.3.0`** du Compose est **non-standard** côté officiel. **Recommandé** : **`mysql:8.4` (LTS)**, sinon 9.0.x après validation compat.

---

## 2) Stockage (Longhorn)
- **Global** : `numberOfReplicas=2` (défaut), `allowVolumeExpansion=true`, `dataLocality=best-effort`.
- **SC DB dédiée** : **`longhorn-db`** → `numberOfReplicas=3`, `fsType=xfs`, `WaitForFirstConsumer`.
- **Backups Longhorn** : **BackupTarget S3** + **RecurringJobs** (snapshot **horaire**, backup **quotidien**).
- **Réalité 1 nœud** : la réplication Longhorn **n’apporte pas** de HA réelle. Accepter SLA réduit jusqu’à ≥2 nœuds.

---

## 3) Réseau
- **Ingress NGINX** : HSTS, TLS ≥1.2, redirection HTTP→HTTPS, `server_tokens off`, `proxy-body-size` adapté.
- **DNS** : external-dns (provider actuel **OVH**, prêt pour **Cloudflare**).
- **Services** :
  - **XWiki** : `ClusterIP` + **Ingress**.
  - **MySQL** : `ClusterIP` (jamais exposé en public).

---

## 4) Sécurité
- **NetworkPolicies (zéro-trust)** : 
  - **Default deny** par namespace (Ingress/Egress).
  - Autoriser **ingress-nginx → XWiki:8080** ; **XWiki → MySQL:3306** ; **apps → kube-dns:53 tcp/udp** ; **cert-manager ↔ ACME** ; **external-dns → provider**.
- **Pod Security Standards** : `restricted` si possible (sinon `baseline`). 
  - `runAsNonRoot: true`, `readOnlyRootFilesystem: true` (sauf DB), `seccompProfile: RuntimeDefault`, `capabilities.drop: [ALL]`, `allowPrivilegeEscalation: false`.
- **Secrets** :
  - **SOPS + age** pour secrets applicatifs (XWiki DB).
  - **Vault + External Secrets Operator** pour secrets infra (ACME, external‑dns, root DB).
- **RBAC** : accès admin **limité** (un seul ClusterRoleBinding admin).

---

## 5) Observabilité & logs
- **kube-prometheus-stack** : Prometheus, Alertmanager, Grafana.
- **Dashboards** : cluster, **Longhorn**, **MySQL** (latence, buffer pool, connexions), XWiki/Tomcat (via JMX si besoin).
- **Logs** : minimal `kubectl logs` ; **Loki (option light)** si centralisation nécessaire.
- **Alertes de base** : Pod/Node down, disk pressure, certs expirants, Longhorn volume **degraded**, 5xx Ingress, PVC errors.

---

## 6) Backups & DR
- **XWiki** : **conserver l’API d’export** via **CronJob** K8s → push **S3** (rétention).
- **MySQL** (option +) : `mysqldump`/`xtrabackup` via **CronJob** → S3 (cohérence logique).
- **Longhorn** : snapshots + backups S3 = second filet de sécurité.
- **Runbooks** (obligatoires) :
  - Restore **XWiki export** (pas-à-pas).
  - Restore **PVC Longhorn** (attach/restore + vérifs).
  - Tests de restore **réguliers** (staging).

---

## 7) CI / GitOps / Industrialisation
- **FluxCD** : GitRepository + Kustomizations (apps/infra).
- **Renovate** : auto‑PR (images/charts), **pin par digest** en prod.
- **Trivy** : scans images **bloquants** dans la CI.
- **Branches & PR** : une PR par bump, pas de merge automatique sans smoke tests.

---

## 8) Déploiement (Ansible)
**Rôles** (tags) : 
- `longhorn` (install, SC défaut + `longhorn-db`, BackupTarget, RecurringJobs)
- `ingress_nginx` (chart/values, headers durs)
- `cert_manager` (ClusterIssuer **staging** + **prod**)
- `external_dns` (OVH; Cloudflare prêt)
- `observability` (kube-prometheus-stack, metrics-server, Loki optionnel)
- `mysql_ss` (Secret, ConfigMap, Service headless, StatefulSet, PVC 50 Gi)
- `xwiki_app` (ConfigMap/Secret, Deployment, Service, Ingress, PVC, CronJob backup API)
- `netpol` (default deny + allow spécifiques)
- `backups` (CronJobs Longhorn/XWiki/MySQL, policies S3)

**Arbo GitOps** : `infra/{longhorn,ingress,cert-manager,external-dns,observability}`, `apps/{mysql,xwiki}`, `policies/`.

---

## 9) Décisions à figer (bloquantes / structurantes)
1. **Version MySQL** : **`mysql:8.4` LTS** recommandé. 9.x seulement après lecture release notes + test compat XWiki.
2. **S3** : **endpoint/provider**, **bucket/prefix**, **région**, **chiffrement** (SSE‑S3 / SSE‑KMS), **rétention**.
3. **FQDN** prod/staging exacts (OVH aujourd’hui ; TTL bas 24–48 h avant cutover).
4. **RPO/RTO** officiels + **fréquence** des tests de restore (mensuelle/trimestrielle).

**Importants (semaine)** : NetPol ports finaux, JVM XWiki (heap/GC/MaxGCPauseMillis=200), tunning MySQL (InnoDB, max_connections), quotas Longhorn (`rebuildReservedBandwidth`), périmètre SOPS vs Vault/ESO, règles Renovate (digest pinning).

---

## 10) Check‑list Prod
- [ ] **SC `longhorn-db`** (réplicas=3, xfs, expansion) OK.
- [ ] **MySQL** (PVC 50 Gi bound, probes green, CRUD perf smoke).
- [ ] **XWiki** via **Ingress TLS** (LE prod), headers durcis, redirects OK.
- [ ] **NetworkPolicies** effectives (tests deny/allow).
- [ ] **Backups** XWiki + Longhorn **tournent** ; **restore validé** en staging.
- [ ] **Dashboards** Grafana (cluster/Longhorn/MySQL) + alertes de base.
- [ ] **Runbooks** à jour ; **plan de rollback** documenté.
- [ ] **Renovate** actif ; images **pinned** ; **Trivy** bloquant.

---

## 11) Prochaines étapes opérationnelles
1. **Valider** les décisions §9 (MySQL, S3, FQDN, RPO/RTO).
2. **Générer** les rôles Ansible + templates `.j2` et pousser dans le repo GitOps.
3. **Déployer en staging** complet ; exécuter **tests de restore**.
4. **Préparer le cutover** : TTL DNS, fenêtre, runbook + rollback ; bascule prod.

---

_Ton garde‑fou : tant que **MySQL**, **S3**, **FQDN** et **RPO/RTO** ne sont pas verrouillés, **pas de prod**._

