
# Open4Goods — Sprint Planning (itérations 1 jour)

> Objectif : avancer par incréments quotidiens, en traitant d’abord l’infra critique puis la migration applicative, la sécurité, l’observabilité et enfin l’industrialisation.

---

## Sprint 1 — Bootstrap cluster
- Story 1.1 : Déployer Longhorn (`replicas=1`) pour volumes persistants.
- Story 1.4 : Créer namespaces (`prod`, `integration`, `recette`, `observability`) avec labels.

---

## Sprint 2 — Ingress & Certificats
- Story 1.2 : Installer ingress-nginx en hostNetwork pour exposer ports 80/443.
- Story 1.3 : Installer cert-manager (ClusterIssuer staging + prod).

---

## Sprint 3 — MySQL
- Story 2.1 : Déployer StatefulSet MySQL 8.0.x avec PVC 50 Gi (`longhorn-db`, xfs).
- Configurer probes MySQL (`:3306`).

---

## Sprint 4 — XWiki
- Story 2.2 : Déployer Deployment XWiki 17.3.0 (mono-réplica) avec PVC `xwiki-data`.
- Story 2.3 : Exposer XWiki via Ingress TLS (`xwiki.logo-solutions.fr`).

---

## Sprint 5 — Sécurité de base
- Story 3.1 : Activer Pod Security Standards (`restricted` si possible).  
- Story 3.2 : Appliquer NetworkPolicies (deny par défaut + règles minimales).

---

## Sprint 6 — Secrets & Policies
- Story 3.3 : Gérer secrets applicatifs via SOPS + age.  
- Story 3.4 : Kyverno : digest obligatoire, interdiction `:latest`, registries autorisés, runAsNonRoot, ressources obligatoires.

---

## Sprint 7 — Observabilité
- Story 4.1 : Installer kube-prometheus-stack (Prometheus + Grafana + Alertmanager).  
- Story 4.2 : Collecter métriques Longhorn via ServiceMonitor.

---

## Sprint 8 — Exporters & Alertes
- Story 4.3 : Déployer mysqld-exporter (sidecar).  
- Story 4.4 : Définir alertes critiques (cert expirations, volume degraded, PV >80%, 5xx ingress).

---

## Sprint 9 — Backups
- Story 5.1 : Automatiser CronJob XWiki export API → S3.  
- Story 5.2 : Automatiser CronJob mysqldump → S3.

---

## Sprint 10 — Runbooks & Tests
- Story 5.3 : Documenter runbook restore XWiki export.  
- Story 5.4 : Tester restauration en staging (mensuel, RPO=24h/RTO=4h).

---

## Sprint 11 — CI/CD
- Story 6.1 : Installer GitHub Runner auto‑hébergé dans K8s.  
- Story 6.2 : Intégrer Trivy dans la CI (fail High/Critical).

---

## Sprint 12 — GitOps & Renovate
- Story 6.3 : Déployer FluxCD (GitRepository + Kustomizations).  
- Story 6.4 : Configurer Renovate pour auto‑PR images/charts, pin digest.

---

## Sprint 13 — Cutover (préparation)
- Story 7.1 : Réduire TTL DNS Hostinger à 300s.  
- Story 7.2 : Geler contenus XWiki, export final + dump MySQL.

---

## Sprint 14 — Cutover (exécution)
- Story 7.3 : Import données dans K8s, tests en staging, switch DNS.  
- Story 7.4 : Vérifier NetPol, probes, backups, dashboards avant défreeze.


