Descriptions des Epics

Epic 1 — Infrastructure & Bootstrap

Mettre en place les briques de base du cluster Kubernetes sur Hetzner : stockage (Longhorn), exposition (ingress-nginx), certificats (cert-manager), namespaces, et configuration initiale.
⚡ Valeur : obtenir un cluster prêt à héberger des workloads avec des volumes persistants, du TLS automatisé et un découpage clair des environnements.

⸻

Epic 2 — Base Applicative (MySQL + XWiki)

Migrer les services MySQL et XWiki du docker-compose vers Kubernetes.
⚡ Valeur : disposer d’un socle applicatif fonctionnel et persistant (DB + Wiki) dans le cluster, avec exposition sécurisée via Ingress.

⸻

Epic 3 — Sécurité & Gouvernance

Appliquer des politiques de sécurité par défaut : Pod Security Standards, NetworkPolicies, gestion des secrets, RBAC minimaliste, règles Kyverno (digest obligatoire, no :latest, runAsNonRoot, etc.).
⚡ Valeur : réduire la surface d’attaque et garantir la conformité des déploiements.

⸻

Epic 4 — Observabilité & Alertes

Installer et configurer la chaîne de monitoring/logging (kube-prometheus-stack, Grafana, Alertmanager, Loki optionnel). Ajouter les exporters (MySQL, Longhorn, JMX XWiki si besoin) et des règles d’alerting basiques.
⚡ Valeur : assurer la visibilité de l’état du cluster et des applis, détecter les pannes/incidents avant les utilisateurs.

⸻

Epic 5 — Backups & Disaster Recovery

Mettre en place les sauvegardes applicatives (XWiki export API, mysqldump) vers S3 + runbooks de restauration. Préparer à terme l’usage de Longhorn backups.
⚡ Valeur : garantir la continuité d’activité en cas de perte de données ou crash du VPS.

⸻

Epic 6 — CI/CD & GitOps

Industrialiser les flux : GitHub Runner dans K8s, scans Trivy bloquants, synchronisation GitOps avec FluxCD, Renovate pour les auto-PR.
⚡ Valeur : fiabiliser et automatiser la livraison applicative, éviter le drift entre Git et cluster.

⸻

Epic 7 — Mise en production & Cutover

Organiser la migration finale de l’ancien setup docker-compose vers le cluster K8s : réduction TTL DNS, freeze contenu, export final, import, smoke tests, switch DNS, défreeze.
⚡ Valeur : bascule en production stable avec un plan clair, validé et réversible.

