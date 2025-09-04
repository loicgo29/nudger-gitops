
# Open4Goods — Spécification synthétique (XWiki + MySQL → Kubernetes via Ansible)

> **But** : migrer le Docker Compose (XWiki + MySQL) en **Kubernetes** avec **Longhorn**, **sécurité par défaut**, **observabilité**, **sauvegardes**, et **GitOps**. Approche **Ansible-first** (rôles + templates), **scalabilité limitée** (XWiki mono‑réplica), **résilience prioritaire**.

---

## 1) Architecture générale
- **Cible initiale** : 1 nœud (master1). ⚠️ Tolérance de panne limitée jusqu’à ajout de nœuds.
- **Applications** : 
  - **XWiki 17.3.0-mysql-tomcat** — 1 replica, PVC RWO `xwiki-data` (ext4).
  - **MySQL** — StatefulSet, PVC RWO 50 Gi `mysql-data` (xfs), **SC `longhorn-db`**.
- **Exposition** : un **IngressController NGINX** (L7), **cert-manager** (ACME HTTP‑01), **external-dns** (OVH → Cloudflare possible).
- **Namespaces** : `open4goods-prod`, `open4goods-integration,open4goods-recette`, `ingress-nginx`, `cert-manager`, `external-dns`, `observability`.
- **image Mysql** : MySQL 8.0.x (LTS) 
  - ConfigMap MySQL avec utf8mb4 + utf8mb4_unicode_ci (aligné avec ton compose).
- **Image xwiki** : xwiki:17.3.0-mysql-tomcat"
- Gitops best practices
---

1) Périmètre Ansible vs GitOps (clarifie et verrouille)
	•	Ansible = bootstrap & infra partagée (une fois ou peu fréquent) : CRDs, Helm charts d’infra (Longhorn, ingress-nginx, cert-manager, external-dns, kube-prom-stack), namespaces/PSA, SC, RBAC de base.
	•	GitOps (FluxCD) = tout le reste en continu : manifests/Helm de l’app (XWiki, MySQL), NetPol, Issuers, RecurringJobs, CronJobs backups.
👉 Action : interdire les kubectl apply Ansible sur les apps; ne déployer les apps que via Flux.

-----
3) Idempotence & Qualité Ansible
	•	Utiliser modules (kubernetes.core.helm, kubernetes.core.k8s) plutôt que shell:/command:.
	•	Versionner strictement (chart versions, app versions).
	•	Inventaires séparés + group_vars par env ; tags infra/apps.
👉 Action : ajoute un check Ansible qui fail si des tâches tentent de toucher un namespace “apps”.
-----
2) Manifests appli : Kustomize ou Helm, mais pas “yaml brut”
	•	Kustomize : clean pour overlays prod/re7/int.
	•	Helm : pratique si tu veux des valeurs paramétrables (ressources, ingress, probes).
👉 Action : choisis un format par app. Si XWiki n’a pas de chart officiel solide, fais un petit chart maison (tests helm template en CI).
-----
## 2) Stockage (Longhorn)
- **Global** : `numberOfReplicas=1` (défaut), `allowVolumeExpansion=true`, `dataLocality=best-effort`.
- **SC DB dédiée** : **`longhorn-db`** → `numberOfReplicas=3`, `fsType=xfs`, `WaitForFirstConsumer`.
- **Réalité 1 nœud** : la réplication Longhorn **n’apporte pas** de HA réelle. 

---

## 3) Réseau
- **Ingress NGINX** : HSTS, TLS ≥1.2, redirection HTTP→HTTPS, `server_tokens off`, `proxy-body-size` adapté.
  - hebergement chez hetzner
- **DNS** : external-dns (provider actuel **hostinger**, prêt pour **Cloudflare**).
- **Services** :
  - **XWiki** : `ClusterIP` + **Ingress**.
  - **MySQL** : `ClusterIP` (jamais exposé en public).
- **FQDN** prod/integration/recette : hostinger : logo-solutions.fr
---

## 4) Sécurité
- **NetworkPolicies (zéro-trust)** : 
  - **Default deny** par namespace (Ingress/Egress).
  - Autoriser **ingress-nginx → XWiki:8080** ; **XWiki → MySQL:3306** ; **apps → kube-dns:53 tcp/udp** ; **cert-manager ↔ ACME** ; **external-dns → provider**.
  - 👉 Action : pack “policies de base” réutilisable par namespace.
- **Pod Security Standards** : `restricted` si possible (sinon `baseline`). 
  - `runAsNonRoot: true`, `readOnlyRootFilesystem: true` (sauf DB), `seccompProfile: RuntimeDefault`, `capabilities.drop: [ALL]`, `allowPrivilegeEscalation: false`.
- **Secrets** :
  - **SOPS + age** pour secrets applicatifs (XWiki DB).
  - **Vault + External Secrets Operator** pour secrets infra (ACME, external‑dns, root DB).
  - 👉 Action : interdiction de Secret en clair dans git (pré-commit hook qui fail si kind: Secret sans .sops.yaml).
- **RBAC** : accès admin **limité** (un seul ClusterRoleBinding admin).
- 	2.	Pinner par digest (éviter le drift des tags)
	•	Remplacer :tag par @sha256:… dans les manifests.
- 
	3.	Limiter la surface d’attaque côté cluster
	•	Kyverno: interdire :	•	interdiction :latest,
	•	digest obligatoire,
	•	registries autorisés,
	•	runAsNonRoot, ressources obligatoires, readOnlyRootFilesystem sauf tier=db.
    	En integration/recette en Audit, en prod en Enforce.
    - 
---
	8.	Ressources
	•	Tu utilises -Xmx1g → requests ≥ 1.2–1.5Gi pour XWiki (headroom GC), limits ~ 2Gi.
	•	MySQL : surveille buffer pool, max_connections → ajuste après premier profil.
  -----

## 5) Observabilité & logs
- **kube-prometheus-stack** : Ensuite tu ajoutes ce qui manque : Longhorn (ServiceMonitor) et MySQL exporter. Optionnel: JMX exporter pour XWiki/Tomcat.
- **Dashboards** : cluster, **Longhorn**, **MySQL** (latence, buffer pool, connexions), XWiki/Tomcat (via JMX si besoin).
- **Logs** : minimal `kubectl logs` ; **Loki (option light)** si centralisation nécessaire.
- **Alertes de base** : Pod/Node down, disk pressure, certs expirants, Longhorn volume **degraded**, 5xx Ingress, PVC errors.
  - 	•	Alertes : cert expirations, PV >80%, OOMKill, 5xx ingress, rebuild Longhorn trop long.


9) Gouvernance & garde-fous
	•	Kyverno pour imposer : runAsNonRoot, readOnlyRootFilesystem, resources obligatoires, interdiction de LoadBalancer en prod, etc.
👉 Action : 3-4 policies “essentielles” pour commencer.
---

## 6) Backups & DR
- **XWiki** : **conserver l’API d’export** via **CronJob** K8s → push **S3** (rétention).
- **MySQL** (option +) : `mysqldump`/`xtrabackup` via **CronJob** → S3 (cohérence logique).
- **Backups Longhorn** : Aucun. la base mysql sera sauvegardé avec lies apis xwiki.BackupTarget vide/configurable, même si tu n’actives pas les RecurringJobs tout de suite
- **Runbooks** (obligatoires) :
  - Restore **XWiki export** (pas-à-pas).


---

## 7) CI / GitOps / Industrialisation
- **FluxCD** : GitRepository + Kustomizations (apps/infra).
- **Renovate** : auto‑PR (images/charts), **pin par digest** en prod pour bumps chart/images.
- **github CI**
- **Gihub Runner** : 	Runner GitHub auto-hébergé dans K8s. A installer sur k8s avant le xwiki
- **Trivy** : scans images **bloquants** dans la CI.
- **Branches & PR** : une PR par bump, pas de merge automatique sans - Signature & provenance (optionnel avancé) : cosign + attestations.
👉 Action : pipeline “build → scan → template (helm/kustomize) → kubeval/kubelinter → PR GitOps”.

---

## 8) Déploiement (Ansible)
**Rôles** (tags) : 
- `longhorn` (install, SC défaut + `longhorn-db`)
- `ingress_nginx` (chart/values, headers durs)
- `cert_manager` (ClusterIssuer **staging** + **prod**)
- `external_dns` (OVH; Cloudflare prêt)
- `observability` (kube-prometheus-stack, metrics-server, Loki optionnel)
- `mysql_ss` (Secret, ConfigMap, Service headless, StatefulSet, PVC 50 Gi)
- `xwiki_app` (ConfigMap/Secret, Deployment, Service, Ingress, PVC, CronJob backup API)
- `netpol` (default deny + allow spécifiques)
- `backups`: aucun dans un 1er temps. les sauvegardes se font via l'api xwiki

**Arbo GitOps** : `infra/{longhorn,ingress,cert-manager,external-dns,observability}`, `apps/{mysql,xwiki}`, `policies/`.

---

## 9) Décisions à figer (bloquantes / structurantes)
1. **FQDN** prod/integration/recette exacts (OVH aujourd’hui ; TTL bas 24–48 h avant cutover).

**A definir ** : NetPol ports finaux, JVM XWiki (heap/GC/MaxGCPauseMillis=200), tunning MySQL (InnoDB, max_connections), quotas Longhorn (`rebuildReservedBandwidth`), périmètre SOPS vs Vault/ESO, règles Renovate (digest pinning).

---

## 10) Check‑list Prod
- [ ] **SC `longhorn-db`** (réplicas=3, xfs, expansion) OK.
- [ ] **MySQL** (PVC 50 Gi bound, probes green, CRUD perf smoke).
- [ ] **XWiki** via **Ingress TLS** (LE prod), headers durcis, redirects OK.
  - [ ] 	XWiki : probe HTTP sur / ok, mais je conseille un endpoint plus robuste (/xwiki/ si contextPath).
  - [ ] proxy-body-size: “adapté” ≠ valeur. Mets une valeur (ex. 100m) selon tes pièces jointes.
- [ ] **NetworkPolicies** effectives (tests deny/allow).
- [ ] **Backups** XWiki + Longhorn **tournent** ; **restore validé** en staging.
- [ ] **Dashboards** Grafana (cluster/Longhorn/MySQL) + alertes de base.
- [ ] **Renovate** actif ; images **pinned** ; **Trivy** bloquant.
-- **Restore XWiki export (API XWiki)** : fichier .xar généré par la sauvegarde API XWiki & Vérifier que les pages, utilisateurs, espaces sont bien restaurés.
---

## 11) Prochaines étapes opérationnelles
1. **Générer** les rôles Ansible + templates `.j2` et pousser dans le repo GitOps.
2. **Déployer en integration** complet ;


