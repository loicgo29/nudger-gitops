
# Open4Goods — Epics & User Stories

## Epic 1 — Infrastructure & Bootstrap
**But** : Préparer le cluster Kubernetes de base avec Ansible (1 VPS Hetzner).

### Stories
- **Story 1.1** : En tant qu’admin, je veux déployer Longhorn (`replicas=1`) pour disposer de volumes persistants.  
- **Story 1.2** : En tant qu’admin, je veux installer ingress-nginx en hostNetwork pour exposer les services en HTTPS sur l’IP publique du VPS.  
- **Story 1.3** : En tant qu’admin, je veux installer cert-manager (ClusterIssuer staging + prod) pour obtenir des certificats Let’s Encrypt.  
- **Story 1.4** : En tant qu’admin, je veux créer les namespaces (`prod`, `integration`, `recette`, `observability`) avec labels `environment=` pour cloisonner les ressources.

---

## Epic 2 — Base Applicative (MySQL + XWiki)
**But** : Migrer MySQL et XWiki de docker-compose vers Kubernetes.

### Stories
- **Story 2.1** : En tant que dev, je veux déployer un StatefulSet MySQL 8.0.x avec PVC 50 Gi (`longhorn-db`, xfs) pour la base persistante.  
- **Story 2.2** : En tant que dev, je veux déployer un Deployment XWiki 17.3.0 (mono-réplica) avec PVC `xwiki-data` (ext4) pour stocker le permanent dir.  
- **Story 2.3** : En tant qu’admin, je veux exposer XWiki via Ingress TLS (`xwiki.logo-solutions.fr`) pour y accéder en HTTPS.  
- **Story 2.4** : En tant qu’admin, je veux configurer les probes readiness/liveness (XWiki `/xwiki/`, MySQL `:3306`) pour garantir l’état des pods.

---

## Epic 3 — Sécurité & Gouvernance
**But** : Appliquer les principes de “secure by default”.

### Stories
- **Story 3.1** : En tant qu’admin, je veux activer Pod Security Standards (`restricted`) pour limiter les permissions pods.  
- **Story 3.2** : En tant qu’admin, je veux appliquer des NetworkPolicies (deny par défaut + règles minimales).  
- **Story 3.3** : En tant qu’admin, je veux gérer mes secrets applicatifs via SOPS + age pour éviter les secrets en clair.  
- **Story 3.4** : En tant qu’admin, je veux que Kyverno impose digest obligatoire, interdiction `:latest`, registries autorisés, `runAsNonRoot`, ressources obligatoires.

---

## Epic 4 — Observabilité & Alertes
**But** : Assurer la supervision et la visibilité de l’environnement.

### Stories
- **Story 4.1** : En tant qu’admin, je veux installer kube-prometheus-stack pour avoir Prometheus + Grafana + Alertmanager.  
- **Story 4.2** : En tant qu’admin, je veux collecter les métriques Longhorn via ServiceMonitor et dashboard dédié.  
- **Story 4.3** : En tant qu’admin, je veux déployer mysqld-exporter (sidecar) pour collecter des métriques MySQL.  
- **Story 4.4** : En tant qu’admin, je veux définir des alertes critiques : cert expirations, volume Longhorn degraded, PVC full >80%, Ingress 5xx.

---

## Epic 5 — Backups & Disaster Recovery
**But** : Garantir la résilience et la restauration des données.

### Stories
- **Story 5.1** : En tant qu’admin, je veux automatiser un CronJob XWiki export API vers S3 pour protéger le contenu fonctionnel.  
- **Story 5.2** : En tant qu’admin, je veux automatiser un CronJob mysqldump vers S3 pour protéger la base.  
- **Story 5.3** : En tant qu’admin, je veux documenter un runbook restore XWiki export.  
- **Story 5.4** : En tant qu’admin, je veux tester mensuellement en staging la restauration XWiki + MySQL pour valider RPO=24h / RTO=4h.

---

## Epic 6 — CI/CD & GitOps
**But** : Industrialiser le pipeline et la gestion applicative.

### Stories
- **Story 6.1** : En tant qu’admin, je veux installer un GitHub Runner auto‑hébergé dans K8s pour exécuter les workflows CI.  
- **Story 6.2** : En tant que dev, je veux que Trivy scanne mes images dans la CI et bloque en cas de vulnérabilité High/Critical.  
- **Story 6.3** : En tant qu’admin, je veux que FluxCD synchronise mes manifests GitOps (infra + apps).  
- **Story 6.4** : En tant que dev, je veux que Renovate crée des auto‑PR pour bumps chart/images, avec pin digest en prod.

---

## Epic 7 — Mise en production & Cutover
**But** : Assurer une bascule sans perte de données ni interruption majeure.

### Stories
- **Story 7.1** : En tant qu’admin, je veux réduire le TTL DNS Hostinger à 300s avant migration pour accélérer le switch.  
- **Story 7.2** : En tant qu’admin, je veux geler les contenus XWiki, effectuer un export final et un dump MySQL avant cutover.  
- **Story 7.3** : En tant qu’admin, je veux importer les données dans le cluster K8s, tester en staging, puis switcher le DNS vers le nouveau service.  
- **Story 7.4** : En tant qu’admin, je veux vérifier que les NetPol, probes, backups et dashboards sont actifs avant défreeze.

