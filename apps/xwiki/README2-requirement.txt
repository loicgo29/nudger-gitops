1) Contexte & objectifs
	•	Cible : cluster K8s (départ : 1 nœud), déploiement via Ansible (rôles + templates), GitOps (FluxCD).
	•	Applis : XWiki 17.3.0-mysql-tomcat (1 replica), MySQL (StatefulSet).
	•	Stockage : Longhorn (SC DB dédiée longhorn-db).
	•	Priorité : résilience (sauvegardes/restores) > scalabilité horizontale (XWiki mono-réplica).
	•	Exposition : Ingress NGINX (TLS LE), external-dns, cert-manager.
	•	Sécu : NetworkPolicies “default deny”, PodSecurity standards, SOPS/age (+ Vault/ESO pour secrets infra).
	•	Observabilité : kube-prometheus-stack (Prom/Alert/Grafana), métriques cluster/Longhorn/MySQL, logs simples (stdout) ou Loki.

⚠️ Point de vigilance immédiat : l’image mysql:9.3.0 n’existe pas côté officiel Docker Hub (branche LTS 8.4, 9.0.x en preview). À corriger/valider.

⸻

2) Architecture cible (vue d’ensemble)
	•	Namespaces : open4goods-prod, open4goods-staging, ingress-nginx, cert-manager, external-dns, observability.
	•	XWiki : Deployment (replicas=1), Service ClusterIP, Ingress TLS, 1 PVC RWO (xwiki-data, ext4).
	•	MySQL : StatefulSet, Service ClusterIP, 1 PVC RWO 50Gi (extensible, xfs, SC longhorn-db).
	•	Ingress : NGINX L7 unique, HSTS, TLS 1.2+, HTTP→HTTPS, server_tokens off, proxy-body-size adapté.
	•	DNS : external-dns (OVH aujourd’hui, Cloudflare demain possible).
	•	Certs : cert-manager (ClusterIssuer LE staging + prod).

⸻

3) Stockage & Longhorn
	•	SC par défaut : replicas=2, expansion activée.
	•	SC DB longhorn-db (MySQL) : replicas=3, dataLocality=best-effort, xfs, allowVolumeExpansion=true.
	•	Backups : BackupTarget S3 + RecurringJobs (snapshots horaires, backups quotidiens).
	•	Anti-affinité réplicas Longhorn (nœuds/zonings différents) — à effet limité tant que tu n’as qu’un seul nœud.
	•	Réalité 1 nœud : réplication Longhorn ≠ tolérance de panne. Accepte la réduction de SLA jusqu’à ajout de nœuds.

⸻

4) Réseau & sécurité
	•	NetworkPolicies (zéro-trust par namespace) :
	•	Default deny ingress/egress.
	•	Allow : ingress-nginx → XWiki:8080, XWiki → MySQL:3306, apps → kube-dns:53 tcp/udp, cert-manager ↔ ACME 80/443, external-dns → provider.
	•	Pod Security : restricted si possible (sinon baseline) :
	•	runAsNonRoot: true, readOnlyRootFilesystem: true (sauf DB), seccompProfile: RuntimeDefault, capabilities.drop: [ALL].
	•	RBAC : éviter les ClusterRoleBinding larges. Un admin toi seul.

⸻

5) Observabilité & logs
	•	kube-prometheus-stack : Prometheus, Alertmanager, Grafana.
	•	Dashboards : cluster, Longhorn, MySQL (latences, buffer pool, connections), XWiki/Tomcat (si JMX).
	•	Logs : minimal kubectl logs OK; Loki (option light) si centralisation nécessaire.
	•	Alerting : règles de base (PVC en erreur, pod crashloop, Longhorn volume degraded, certs expirants, 5xx Ingress).

⸻

6) Backups & restauration (DR)
	•	XWiki : cronjob K8s qui appelle l’API d’export XWiki → push S3 (avec rétention).
	•	MySQL (optionnel +) : mysqldump/xtrabackup via CronJob → S3 (cohérence logique).
	•	Longhorn : snapshots + backups S3 comme filet de sécu.
	•	Runbooks :
	•	Restore XWiki export (décrit pas à pas).
	•	Restore PVC Longhorn (attach/restore, verifs post-restore).
	•	Tests réguliers de restore (staging).

⸻

7) CI/GitOps & images
	•	FluxCD déjà en place (GitRepository/Kustomizations).
	•	Renovate : activé pour bump images/charts.
	•	Trivy (CI) : scan images blocking.
	•	Pin images par digest (@sha256:) quand possible (prod).

⸻

8) Ressources & santé
	•	XWiki : requests (ex. 200m CPU, 512Mi RAM) / limits (2 CPU, 2Gi) + readinessProbe/livenessProbe HTTP (tomcat).
	•	MySQL : requests (ex. 500m CPU, 1–2Gi RAM) / limits (1–2 CPU, 3–4Gi) ; config utf8mb4 + collation ; probes TCP/exec.
	•	QoS : éviter le throttling lors de rebuild Longhorn → poser des requests explicites.

⸻

9) Secrets & config
	•	SOPS + age : secrets applicatifs (XWiki DB creds).
	•	Vault + ESO : secrets infra (ACME account, external-dns tokens, root DB). Option : tout basculer sous Vault à terme.
	•	ConfigMaps : JAVA_OPTS, conf MySQL (charset/collation).
	•	Jamais exposer MySQL en public. ClusterIP only.

⸻

10) Plan de déploiement (Ansible)
	•	Rôles (tags) :
	•	longhorn : install + SC défaut + SC longhorn-db + backupTarget + recurringJobs.
	•	ingress : ingress-nginx + annotations TLS/headers.
	•	certs : cert-manager + ClusterIssuers (staging/prod).
	•	external_dns : provider OVH (Cloudflare prêt).
	•	observability : kube-prometheus-stack (+ Loki option).
	•	mysql_ss : StatefulSet, Service, PVC.
	•	xwiki : Deployment, Service, Ingress, ConfigMap, Secret, CronJobs backup API.
	•	netpol : default deny + allow spécifiques.
	•	backups : CronJobs Longhorn/XWiki/MySQL, policies S3.
	•	GitOps repo : apps/xwiki/, apps/mysql/, infra/longhorn/, infra/ingress/, infra/cert-manager/, infra/external-dns/, infra/observability/, policies/.
	•	Livrables : templates .j2, README par dossier, runbooks restore, fichiers SOPS.

⸻

11) Check-list prod (à cocher)
	•	Image MySQL corrigée (8.4 LTS ? 9.0.x validée ?) + conf charset/collation.
	•	StorageClass longhorn-db (xfs, replicas=3, expansion OK).
	•	MySQL OK (PVC 50Gi bound, probes green, CRUD perf smoke).
	•	XWiki accessible via Ingress TLS (LE prod), headers durcis, redirects OK.
	•	NetworkPolicies testées (deny/allow).
	•	Backups XWiki + Longhorn tournent ; restore testé (staging).
	•	Dashboards Grafana (cluster/Longhorn/MySQL) + alertes basiques.
	•	Renovate actif, Trivy en CI, images pinned.

⸻

12) Décisions à prendre (claires, priorisées)

🔴 Bloquants (à décider maintenant)
	1.	Version MySQL : mysql:9.3.0 est douteux. Choix recommandé :
	•	MySQL 8.4 LTS (officiel), ou
	•	MySQL 9.0.x si validé par release notes et compat XWiki.
	2.	S3 BackupTarget : endpoint, bucket, région, chiffrement, rétention. Qui paye et qui possède les clés ?
	3.	FQDN XWiki (prod/staging) : ex. xwiki.open4goods.fr (aujourd’hui OVH). TTL bas 24–48h avant cutover.
	4.	Politique de restore officielle : RPO/RTO cibles et fréquence de tests de restore (mensuel/trimestriel ?).

🟠 Importants (semaine en cours)
	5.	Scopes NetworkPolicies exacts (ports, namespaces). Liste blanche minimale validée.
	6.	Paramètres JVM XWiki (heap, GC, MaxGCPauseMillis=200 validé ?). Besoin JMX ?
	7.	Dimensionnement MySQL : innodb_buffer_pool_size, max_connections, I/O pattern. Fichier conf à figer.
	8.	Quotas Longhorn : rebuildReservedBandwidth et priorités I/O pendant rebuild (éviter impact XWiki).
	9.	Secrets : périmètre SOPS vs Vault/ESO. Qui gère les clés age/Vault (opérationnellement) ?
	10.	Renovate : règles d’auto-PR (images, charts), inclure digest pinning.

🟡 À clarifier (non bloquants)
	11.	Cloudflare : passage quand ? (CDN/DoS, Page Rules, certs).
	12.	Loki : le veux-tu maintenant ou plus tard ?
	13.	HPA : pas pertinent pour XWiki (stateful assets) ; OK de ne pas en mettre pour l’instant ?
	14.	Anti-affinité pods : utile quand tu auras ≥2 nœuds ; on l’ajoute maintenant (inactive) ou plus tard ?
	15.	Plan multi-environnements : open4goods-staging actif avant cutover prod pour dress rehearsal.

⸻

13) Points de friction (honnêtes)
	•	1 seul nœud : pas de tolérance de panne réelle, même avec Longhorn (réplicas sur même nœud).
	•	XWiki mono-réplica : indispo pendant restart/upgrade → prévoir fenêtres de maintenance.
	•	Rebuild Longhorn : peut throttler l’I/O ; poser des requests et surveiller.
	•	Cutover DNS : effets TTL ; plan de rollback indispensable (A/B).

⸻

14) Prochaines étapes (opérationnelles)
	1.	Valider les décisions 🔴 ci-dessus (MySQL version, S3, FQDN, RPO/RTO).
	2.	Générer les rôles Ansible + templates .j2 (structure §10) avec tags clairs.
	3.	Déployer en staging, tester backups/restore (XWiki export + Longhorn).
	4.	Bascule prod : TTL bas, fenêtre, runbook, rollback documenté.

⸻

Si tu veux, je te fournis ensuite :
	•	les templates .j2 (StatefulSet MySQL, Deployment/Ingress XWiki, SC Longhorn, NetPols),
	•	un playbook Ansible minimal avec tags,
	•	les CronJobs (export XWiki API + backups Longhorn),
	•	les ClusterIssuers (LE staging/prod) + external-dns OVH.

Questions finales (rapides)
	•	MySQL : on part sur 8.4 LTS ?
	•	S3 : donne-moi endpoint / bucket / région / rétention (jours) / chiffrement (SSE-S3 ou SSE-KMS).
	•	FQDN prod/staging exacts ?
	•	RPO/RTO cibles ? (ex. RPO 24h, RTO 2h)
	•	Loki tout de suite ou plus tard ?
	•	Cloudflare : on migre maintenant ou on reste OVH pour la bascule ?

Je reste critique : tant que ces 4 points (image MySQL, S3, FQDN, RPO/RTO) ne sont pas figés, pas de prod.
