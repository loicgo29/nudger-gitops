
# Open4Goods — Spécification synthétique (XWiki + MySQL → Kubernetes via Ansible)

> **But** : migrer le Docker Compose (XWiki + MySQL) en **Kubernetes** avec **Longhorn**, **sécurité par défaut**, **observabilité**, **sauvegardes**, et **GitOps**.  
> Approche **Ansible-first** (rôles + templates), **scalabilité limitée** (XWiki mono‑réplica), **résilience prioritaire**.

---

## 1) Architecture générale
- **Cible initiale** : 1 nœud (master1). ⚠️ Tolérance de panne limitée jusqu’à ajout de nœuds.
- **Applications** : 
  - **XWiki 17.3.0-mysql-tomcat** — 1 replica, PVC RWO `xwiki-data` (ext4).
  - **MySQL** — StatefulSet, PVC RWO 50 Gi `mysql-data` (xfs), **SC `longhorn-db`**.
- **Exposition** : un **IngressController NGINX** (L7), **cert-manager** (ACME HTTP‑01).
- **Namespaces** : `open4goods-prod`, `open4goods-integration`, `open4goods-recette`, `ingress-nginx`, `cert-manager`, `observability`.
- **Image MySQL** : MySQL 8.0.x (LTS)  
  - ConfigMap MySQL avec `utf8mb4` + `utf8mb4_unicode_ci` (aligné avec docker‑compose).
- **Image XWiki** : `xwiki:17.3.0-mysql-tomcat`
- **GitOps best practices**

### Périmètre Ansible vs GitOps
- **Ansible** = bootstrap & infra partagée (rare) : CRDs, Helm charts (Longhorn, ingress-nginx, cert-manager, kube-prom-stack), namespaces/PSA, SC, RBAC de base.
- **GitOps (FluxCD)** = tout le reste : manifests/Helm de l’app (XWiki, MySQL), NetPol, Issuers, RecurringJobs, CronJobs backups.  
👉 **Action** : interdire les `kubectl apply` Ansible sur les apps ; ne déployer les apps que via Flux.

### Idempotence & Qualité Ansible
- Utiliser modules (`kubernetes.core.helm`, `kubernetes.core.k8s`) plutôt que `shell`/`command`.
- Versionner strictement (chart versions, app versions).
- Inventaires séparés + group_vars par env ; tags infra/apps.  
👉 **Action** : ajoute un check Ansible qui fail si des tâches tentent de toucher un namespace “apps”.

### Manifests appli
- **Kustomize** : clean pour overlays prod/re7/int.  
- **Helm** : pratique si tu veux des valeurs paramétrables (ressources, ingress, probes).  
👉 **Action** : choisis un format par app. Si XWiki n’a pas de chart officiel solide, fais un petit chart maison (tests `helm template` en CI).

---

## 2) Stockage (Longhorn)
- **Global** : `numberOfReplicas=1` (défaut, mono‑nœud), `allowVolumeExpansion=true`, `dataLocality=best-effort`.
- **SC DB dédiée** : **`longhorn-db`** → `numberOfReplicas=3`, `fsType=xfs`, `WaitForFirstConsumer`.  
⚠️ Sur un seul nœud, la réplication Longhorn n’apporte pas de HA réelle.

---

## 3) Réseau
- **Ingress NGINX** : HSTS, TLS ≥1.2, redirection HTTP→HTTPS, `server_tokens off`, `proxy-body-size` fixé (ex: 100m).  
  - Hébergement : **Hetzner VPS**
- **DNS** : zone **Hostinger**, pas d’external-dns (non supporté). Migration Cloudflare possible plus tard.
- **Services** :  
  - **XWiki** : `ClusterIP` + **Ingress`  
  - **MySQL** : `ClusterIP` (jamais exposé en public)
- **FQDN** prod/integration/recette : `*.logo-solutions.fr` (Hostinger)
- **Mode d’exposition** : sur un VPS unique → **ingress-nginx en hostNetwork** (ports 80/443 directement sur l’hôte).  
  - Ouvrir 80/443 sur le VPS (firewall Hetzner + UFW/iptables).  
  - Hostinger → HTTP‑01 OK (80 routé vers ingress).  
  - **DNS Hostinger manuel** : créer `A xwiki.logo-solutions.fr → <IP_publique_VPS>`, TTL 300–600 s avant cutover.

---

## 4) Sécurité
- **NetworkPolicies (zéro-trust)** :  
  - Default deny par namespace (Ingress/Egress).  
  - Autoriser ingress-nginx → XWiki:8080 ; XWiki → MySQL:3306 ; apps → kube-dns:53 ; cert-manager ↔ ACME ; external-dns → provider.  
  👉 **Action** : pack “policies de base” réutilisable par namespace.

- **Pod Security Standards** : `restricted` si possible (sinon `baseline`).  
  - `runAsNonRoot: true`, `readOnlyRootFilesystem: true` (sauf DB), `seccompProfile: RuntimeDefault`, `capabilities.drop: [ALL]`, `allowPrivilegeEscalation: false`.

- **Secrets** :  
  - **SOPS + age** pour secrets applicatifs (XWiki DB).  
  - **Vault + ESO** pour secrets infra (ACME, external‑dns, root DB).  
  👉 Action : interdiction de `Secret` en clair dans git (pré-commit hook).

- **RBAC** : admin limité (1 ClusterRoleBinding admin).

- **Image hygiene** :  
  - Pinner par digest (`@sha256:…`).  
  - Kyverno : interdire `:latest`, digest obligatoire, registries autorisés, runAsNonRoot, ressources obligatoires, rootfs RO sauf DB.  
  - En integration/recette : `Audit`, en prod : `Enforce`.

- **Ressources** :  
  - XWiki : `-Xmx1g` → requests ≥ 1.2–1.5Gi, limits ~2Gi.  
  - MySQL : buffer pool + max_connections à ajuster après profil.

---

## 5) Observabilité & logs
- **kube-prometheus-stack** : base.  
- **ServiceMonitors** : Longhorn + MySQL exporter. Optionnel : JMX exporter pour XWiki/Tomcat.
- **Dashboards** : cluster, Longhorn, MySQL, XWiki/Tomcat.  
- **Logs** : `kubectl logs` minimal ; Loki (optionnel) pour centralisation.  
- **Alertes** : Pod/Node down, disk pressure, certs expirants, Longhorn degraded, 5xx Ingress, PVC errors, PV >80%, OOMKill, rebuild Longhorn lent.

- **Gouvernance & garde-fous** : Kyverno pour enforce règles essentielles.  
👉 Action : pack 3–4 policies critiques.

---

## 6) Backups & DR
- **XWiki** : API export via CronJob K8s → S3 (rétention).  
- **MySQL** : mysqldump/xtrabackup via CronJob → S3.  
- **Longhorn backups** : désactivés au départ (BackupTarget vide/configurable).  
- **Runbooks obligatoires** :  
  - Restore XWiki export (pas-à-pas).  
  - Restore PVC Longhorn.

---

## 7) CI / GitOps / Industrialisation
- **FluxCD** : GitRepository + Kustomizations (apps/infra).  
- **Renovate** : auto‑PR (images/charts), pin digest.  
- **GitHub CI** :  
  - Runner GitHub auto-hébergé dans K8s (avant XWiki).  
  - Trivy : scans bloquants.  
  - Pipeline : build → scan → template (helm/kustomize) → kubeval/kubelinter → PR GitOps.

---

## 8) Déploiement (Ansible)
**Rôles** :  
- `longhorn` (install, SC défaut + `longhorn-db`)  
- `ingress_nginx` (chart/values, headers durcis)  
- `cert_manager` (ClusterIssuer staging+prod)  
- `observability` (kube-prometheus-stack, metrics-server, Loki optionnel)  
- `mysql_ss` (Secret, ConfigMap, Service headless, StatefulSet, PVC 50 Gi)  
- `xwiki_app` (ConfigMap/Secret, Deployment, Service, Ingress, PVC, CronJob backup API)  
- `netpol` (default deny + allow spécifiques)  
- `backups` : API XWiki (pas de Longhorn backup initialement)  

**Arbo GitOps** :  
- `infra/{longhorn,ingress,cert-manager,observability}`  
- `apps/{mysql,xwiki}`  
- `policies/`

---

## 9) Décisions à figer
- FQDN prod/integration/recette exacts.  
- NetPol ports finaux.  
- JVM XWiki (heap/GC/MaxGCPauseMillis=200).  
- Tuning MySQL (InnoDB, max_connections).  
- Quotas Longhorn (`rebuildReservedBandwidth`).  
- Périmètre SOPS vs Vault/ESO.  
- Règles Renovate (digest pinning).  
- RPO/RTO (proposition : RPO=24h, RTO=4h).

---

## 10) Check‑list Prod
- [ ] SC `longhorn-db` (xfs, expansion).  
- [ ] MySQL : PVC 50 Gi bound, probes green, CRUD perf OK.  
- [ ] XWiki via Ingress TLS (LE prod), headers durcis, redirect OK.  
  - [ ] Probe HTTP sur `/xwiki/` (plus robuste que `/`).  
  - [ ] `proxy-body-size` fixé (ex. 100m).  
- [ ] NetPol effectives (deny/allow testés).  
- [ ] Backups XWiki + MySQL → S3, restore validé en staging.  
- [ ] Dashboards Grafana (cluster/Longhorn/MySQL) + alertes de base.  
- [ ] Renovate actif, images pinned, Trivy bloquant.

---

## 11) Prochaines étapes
1. Générer les rôles Ansible + templates `.j2`, pousser dans le repo GitOps.  
2. Déployer en integration complet.  

