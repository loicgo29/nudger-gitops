# Generate a detailed Markdown spec and save it as a downloadable file

from textwrap import dedent

md = dedent("""
# Open4Goods — Migration XWiki + MySQL vers Kubernetes (via Ansible)

> **Objectif** : migrer le Docker Compose de prod (XWiki + MySQL) vers K8s, avec stockage Longhorn, sécurité par défaut, observabilité, sauvegardes et GitOps. Déploiement **au travers d’Ansible** (roles + templates Helm/Kustomize), en **priorisant la résilience** (pas la scalabilité horizontale d’XWiki).

# cible
> 1 seul noeud : master1 dans un premier temps 
> déploiement via Ansible (rôles + templates), GitOps (FluxCD).
>Applis : XWiki 17.3.0-mysql-tomcat (1 replica), MySQL (StatefulSet).

---

## 1) Portée et hypothèses (challengées)

- **XWiki**: 1 replica (pas de RWX pour /usr/local/xwiki). Résilience par **backups** (XWiki API + Longhorn) et **anti‑affinity**/topology pour les répliques Longhorn.
- **MySQL**: **StatefulSet** avec **RWO 50 Gi** (extensible), StorageClass **longhorn-db**. 
- **Longhorn (cluster‑wide)**: 
  - Default **replica count = 2** (global), **override = 3** via SC `longhorn-db`.
  - **allowVolumeExpansion = true**, **dataLocality = best-effort**.
  - **Filesystem**: **xfs** pour DB/ES, **ext4** ailleurs.
  - **BackupTarget** S3 + **RecurringJobs** (snapshots horaires, backups quotidiens).
- **Réseau**: un seul IngressController **ingress-nginx** (L7), **external-dns**, **cert‑manager** (ACME HTTP‑01).
- **Sécu**: **NetworkPolicies strictes** (default deny), **Pod Security Standards** (baseline/restricted), **SOPS+age** (app) + **Vault/ESO** (secrets infra).
- **Observabilité**: **kube‑prometheus‑stack** (Prometheus/Alertmanager/Grafana), **metrics‑server**, **Loki** (option light pour logs).
- **Namespaces**: `open4goods-prod`, `open4goods-staging`, `ingress-nginx`, `cert-manager`, `external-dns`, `observability`.
- **DNS/TLS**: aujourd’hui **OVH**, demain **Cloudflare** (compatibles external-dns). **HSTS**, **TLS 1.2+**, redirection **HTTP→HTTPS**, **server_tokens off**, **proxy-body-size** adapté.
- **CI/GitOps**: FluxCD (déjà en place), Renovate (à activer).

> **Alerte** : l’image **`mysql:9.3.0`** dans votre Compose semble **non-standard** (officiel MySQL publie des tags 8.0.x/8.4 LTS/9.0.x). **Décision requise** ci‑dessous.

---

## 2) Cibles techniques (résumé)

| Composant | Type | Stockage | Exposition | HA | Remarques |
|---|---|---|---|---|---|
| XWiki | Deployment (1 replica) | PVC `xwiki-data` (RWO, ext4) | Ingress (TLS) | N/A (réplica unique) | Backups via API XWiki + Longhorn. |
| MySQL | StatefulSet | PVC `mysql-data` (**RWO 50 Gi**, **xfs**), SC `longhorn-db` | ClusterIP | Données répliquées **Longhorn (3)** | Cpu/mem requests/limits, anti‑affinity topo. |
| Ingress | ingress-nginx | – | LoadBalancer/NodePort | – | HSTS, TLS 1.2+, headers durcis. |
| Certs | cert-manager | – | – | – | ClusterIssuer LE staging/prod. |
| DNS | external-dns | – | – | – | Provider OVH → Cloudflare plus tard. |
| Logs | Loki (option light) | – | – | – | `kubectl logs` suffisant sinon. |
| Metrics | kube‑prometheus‑stack | – | – | – | Dashboards Grafana (cluster, Longhorn, MySQL). |

---

## 3) Stockage Longhorn

### 3.1 StorageClass `longhorn-db` (override 3 réplicas, xfs)
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-db
provisioner: driver.longhorn.io
allowVolumeExpansion: true
parameters:
  numberOfReplicas: "3"
  dataLocality: "best-effort"
  fsType: "xfs"
  staleReplicaTimeout: "30"   # minutes
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
```

### 3.2 RecurringJobs (snapshots/backup S3)
```yaml
apiVersion: longhorn.io/v1beta2
kind: RecurringJob
metadata:
  name: hourly-snap
  namespace: longhorn-system
spec:
  name: hourly-snap
  task: snapshot
  cron: "0 * * * *"
  retain: 24
---
apiVersion: longhorn.io/v1beta2
kind: RecurringJob
metadata:
  name: daily-backup
  namespace: longhorn-system
spec:
  name: daily-backup
  task: backup
  cron: "0 3 * * *"
  retain: 7
```
> À attacher au volume via `recurringJobs` ou via Longhorn UI/annotations.

---

## 4) MySQL (StatefulSet)

### 4.1 Secret + ConfigMap
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secrets
  namespace: open4goods-prod
type: Opaque
stringData:
  MYSQL_ROOT_PASSWORD: "xwiki"      # SOPS (prod)
  MYSQL_USER: "xwiki"
  MYSQL_PASSWORD: "xwiki"
  MYSQL_DATABASE: "xwiki"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-config
  namespace: open4goods-prod
data:
  my.cnf: |
    [mysqld]
    character-set-server = utf8mb4
    collation-server     = utf8mb4_unicode_ci
    explicit_defaults_for_timestamp = 1
```

### 4.2 StatefulSet + Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql
  namespace: open4goods-prod
spec:
  clusterIP: None
  selector: { app: mysql }
  ports:
    - name: mysql
      port: 3306
      targetPort: 3306
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
  namespace: open4goods-prod
spec:
  serviceName: mysql
  replicas: 1
  selector:
    matchLabels: { app: mysql }
  template:
    metadata:
      labels: { app: mysql, tier: db, environment: prod }
    spec:
      securityContext:
        fsGroup: 999   # mysql user id (à vérifier selon image)
      containers:
        - name: mysql
          image: "mysql:8.4"   # ⚠️ Décision version (voir §9)
          args: ["--character-set-server=utf8mb4","--collation-server=utf8mb4_unicode_ci"]
          ports: [{ containerPort: 3306, name: mysql }]
          envFrom:
            - secretRef: { name: mysql-secrets }
          volumeMounts:
            - name: data
              mountPath: /var/lib/mysql
            - name: config
              mountPath: /etc/mysql/conf.d
          resources:
            requests:
              cpu: "500m"
              memory: "1Gi"
            limits:
              cpu: "2"
              memory: "2Gi"
          livenessProbe:
            tcpSocket: { port: 3306 }
            initialDelaySeconds: 20
            periodSeconds: 10
          readinessProbe:
            exec:
              command: ["bash","-lc","mysqladmin ping -u root -p$MYSQL_ROOT_PASSWORD"]
            initialDelaySeconds: 10
            periodSeconds: 5
      volumes:
        - name: config
          configMap:
            name: mysql-config
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values: [mysql]
            topologyKey: "kubernetes.io/hostname"
  volumeClaimTemplates:
    - metadata:
        name: data
        annotations:
          recurring-job.longhorn.io/default: '["hourly-snap","daily-backup"]'
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: longhorn-db
        resources:
          requests:
            storage: 50Gi
```

---

## 5) XWiki (Deployment + Service + Ingress)

### 5.1 Config + Secret
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: xwiki-config
  namespace: open4goods-prod
data:
  JAVA_OPTS: "-Xmx1g -Xms1g -XX:+UseG1GC -XX:MaxGCPauseMillis=200"
---
apiVersion: v1
kind: Secret
metadata:
  name: xwiki-db
  namespace: open4goods-prod
type: Opaque
stringData:
  DB_USER: "xwiki"
  DB_PASSWORD: "xwiki"     # SOPS (prod)
  DB_DATABASE: "xwiki"
  DB_HOST: "mysql"
```

### 5.2 Deployment + Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: xwiki
  namespace: open4goods-prod
spec:
  type: ClusterIP
  selector: { app: xwiki }
  ports:
    - name: http
      port: 8080
      targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: xwiki
  namespace: open4goods-prod
spec:
  replicas: 1
  selector:
    matchLabels: { app: xwiki }
  template:
    metadata:
      labels: { app: xwiki, tier: web, environment: prod }
    spec:
      containers:
        - name: xwiki
          image: "xwiki:17.3.0-mysql-tomcat"
          envFrom:
            - configMapRef: { name: xwiki-config }
            - secretRef: { name: xwiki-db }
          ports: [{ containerPort: 8080, name: http }]
          volumeMounts:
            - name: data
              mountPath: /usr/local/xwiki
          resources:
            requests:
              cpu: "500m"
              memory: "1Gi"
            limits:
              cpu: "2"
              memory: "2Gi"
          readinessProbe:
            httpGet: { path: /, port: http }
            initialDelaySeconds: 15
            periodSeconds: 10
          livenessProbe:
            httpGet: { path: /, port: http }
            initialDelaySeconds: 30
            periodSeconds: 20
      volumes: []
  # PVC en dessous
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: xwiki-data
  namespace: open4goods-prod
spec:
  accessModes: ["ReadWriteOnce"]
  storageClassName: longhorn
  resources:
    requests:
      storage: 20Gi
```

### 5.3 Ingress (TLS + headers)
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: xwiki
  namespace: open4goods-prod
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
    nginx.ingress.kubernetes.io/server-snippet: |
      more_clear_headers "Server";
      add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
spec:
  tls:
    - hosts: [ "xwiki.open4goods.example" ]
      secretName: xwiki-tls
  rules:
    - host: xwiki.open4goods.example
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: xwiki
                port: { number: 8080 }
```

---

## 6) Réseau & Sécurité

### 6.1 NetworkPolicies (default deny + autorisations)
```yaml
# Default deny pour le namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: open4goods-prod
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
---
# ingress-nginx -> xwiki
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress-to-xwiki
  namespace: open4goods-prod
spec:
  podSelector:
    matchLabels: { app: xwiki }
  ingress:
    - from:
        - namespaceSelector:
            matchLabels: { name: ingress-nginx }
      ports:
        - protocol: TCP
          port: 8080
---
# xwiki -> mysql:3306, DNS, internet restreint (ACME/external-dns hors prod app)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-xwiki-egress
  namespace: open4goods-prod
spec:
  podSelector:
    matchLabels: { app: xwiki }
  egress:
    - to:
        - podSelector: { matchLabels: { app: mysql } }
      ports:
        - protocol: TCP
          port: 3306
    - to:
        - namespaceSelector: {}
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
  policyTypes: [Egress]
```

### 6.2 Pod Security & hardening
- **Namespace labels** pour PSS: `pod-security.kubernetes.io/enforce=baseline|restricted` (prod/staging).
- **Templates chart** (web/db) : 
  ```yaml
  securityContext:
    runAsNonRoot: true
    readOnlyRootFilesystem: true   # sauf DB
    allowPrivilegeEscalation: false
    seccompProfile: { type: RuntimeDefault }
    capabilities: { drop: ["ALL"] }
  ```
- **Ingress NGINX**: `server_tokens off`, HSTS, TLS1.2+, redirect HTTP→HTTPS.

### 6.3 Secrets
- **SOPS + age** pour secrets applicatifs (XWiki DB creds).
- **Vault + External Secrets Operator** pour secrets infra (ACME, external‑dns, root DB).

---

## 7) Observabilité & Logs

- **kube‑prometheus‑stack** (Prometheus/Alertmanager/Grafana) :
  - Dashboards: **Cluster**, **Longhorn**, **MySQL** (exporter si besoin).
- **metrics‑server** pour HPA.
- **Loki** (option light) ou logs natifs (`kubectl logs`). 
- **Alerting** : starts simple (Pod/Node down, disk pressure, volume unhealthy).

---

## 8) Backups

- **XWiki** : conserver le mécanisme de sauvegarde **via API** (cronjob K8s qui appelle l’API, pousse vers S3).
- **Longhorn** : **snapshots horaires** + **backups quotidiens** vers S3 (voir §3.2).
- **Restauration** : playbooks Ansible dédiés (restore Longhorn PVC + restore XWiki export).

Exemple **CronJob** XWiki:
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: xwiki-backup
  namespace: open4goods-prod
spec:
  schedule: "15 2 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - name: backup
              image: alpine:3.20
              envFrom:
                - secretRef: { name: xwiki-backup-s3 }  # SOPS
              command: ["/bin/sh","-lc"]
              args:
                - >
                  wget --quiet --output-document=/tmp/xwiki-backup.xar "https://xwiki.open4goods.example/export?format=xar&pages=Space.Page&backup=true";
                  aws s3 cp /tmp/xwiki-backup.xar s3://open4goods-backups/xwiki/$(date +%F).xar
```

---

## 9) Décisions à prendre (bloquantes/structurantes)

1. **Version MySQL** : `mysql:8.4` (LTS) **ou** `mysql:9.0+` ? L’image **`mysql:9.3.0`** du Compose paraît **suspecte**. Privilégier **8.4 LTS** pour stabilité, sauf besoin 9.x.
2. **Taille PVC** : confirmer **50 Gi** pour MySQL (**+ growth**). Taille **xwiki-data** (20–50 Gi ?).
3. **S3** : préciser **endpoint/provider**, credentials (Vault/ESO), bucket/prefix & lifecycle.
4. **Domaines** : `xwiki.open4goods.example` → définir **vrai FQDN** (OVH aujourd’hui, Cloudflare demain).
5. **PSS niveau** : `baseline` ou `restricted` pour prod ? (DB requiert `readOnlyRootFilesystem: false`).
6. **Logs** : simple (`kubectl logs`) ou **Loki** minimal tout de suite ?
7. **Renovate** : activer maintenant (pin images/Helm charts) ?
8. **Anti‑affinity** : contraintes **zone/hostname** (selon topo Hetzner) – fournir labels nœuds.
9. **Plan rollback** : stratégie de retour Compose → K8s (fenêtre de bascule, tests).

---

## 10) Plan de migration (phases)

1. **Infra** : installer Longhorn, configurer **BackupTarget S3**, créer **SC longhorn-db**.
2. **Base** : déployer `ingress-nginx`, `cert-manager` (ClusterIssuer staging→prod), `external-dns` (provider actuel).
3. **Observabilité** : `kube-prometheus-stack`, `metrics-server` (HPA ready), (option) **Loki**.
4. **DB** : déployer MySQL **vierge** en staging, initialiser schéma via init container ou dump.
5. **XWiki** : déployer en staging (1 replica), configurer **Ingress+TLS**, vérifier fonctionnalités.
6. **Backups** : CronJob XWiki + RecurringJobs Longhorn → valider **restores**.
7. **Prod cutover** :
   - geler écritures (maintenance),
   - dump MySQL sur Compose,
   - **restore** dans PVC prod,
   - basculer DNS/Ingress,
   - smoke tests, roll back plan prêt.

---

## 11) Ansible — Structure proposée

```
roles/
  longhorn/
    tasks/{install.yml,sc.yml,recurring.yml}
    templates/storageclass-longhorn-db.yaml.j2
    templates/recurringjobs.yaml.j2
  ingress_nginx/
    tasks/main.yml
    templates/values.yaml.j2
  cert_manager/
    tasks/main.yml
    templates/clusterissuers.yaml.j2
  external_dns/
    tasks/main.yml
    templates/values.yaml.j2
  mysql_ss/
    tasks/{secrets.yml,config.yml,ss.yml,svc.yml}
    templates/{secret.yaml.j2,configmap.yaml.j2,ss.yaml.j2,svc.yaml.j2}
  xwiki_app/
    tasks/{config.yml,secret.yml,deploy.yml,svc.yml,ingress.yml,pvc.yml}
    templates/*.yaml.j2
  netpol/
    tasks/main.yml
    templates/{default-deny.yaml.j2,allow-xwiki.yaml.j2,allow-db.yaml.j2}
  observability/
    tasks/{kps.yml,metrics.yml,loki.yml}
  backups/
    tasks/{xwiki-cronjob.yml}
    templates/xwiki-cronjob.yaml.j2
```

**Variables clés** (extraits `group_vars/open4goods-prod.yml`):
```yaml
domain_root: "open4goods.example"
xwiki_host: "xwiki.{{ domain_root }}"
mysql_image: "mysql:8.4"
mysql_storage: "50Gi"
longhorn_backup_s3:
  endpoint: "s3.eu-west-1.amazonaws.com"
  bucket: "open4goods-backups"
  access_key: "...."  # via Vault/ESO
  secret_key: "...."  # via Vault/ESO
```

**Playbook exemple**:
```yaml
- hosts: k8s_masters
  roles:
    - role: longhorn
    - role: ingress_nginx
    - role: cert_manager
    - role: external_dns
    - role: netpol
    - role: observability
    - role: mysql_ss
    - role: xwiki_app
    - role: backups
```

---

## 12) Livrables attendus

- **Repo gitops** : dossiers `apps/xwiki/`, `apps/mysql/`, `infra/longhorn/`, `infra/ingress/`, `infra/cert-manager/`, `infra/external-dns/`, `infra/observability/`, `policies/`.
- **Rôles Ansible** + **templates .j2** ci‑dessus, avec **tags** (`longhorn`, `mysql`, `xwiki`, `ingress`, `certs`, `dns`, `observability`, `netpol`, `backups`). 
- **Docs README.md** par dossier + **RUNBOOKS** (restore Longhorn, restore XWiki).
- **Fichiers SOPS** pour secrets app + **ESO** (Vault) pour secrets infra.
- **Dashboards Grafana** importables (Longhorn, MySQL, cluster).

---

## 13) Risques & garde‑fous (franc)

- **Tag MySQL douteux** (`mysql:9.3.0`) → **bloquant** si non clarifié.
- **Replica unique XWiki** : indispo pendant restart/upgrade → **fenêtre de maintenance** nécessaire.
- **Longhorn rebuild** : coûteux en I/O → poser **requests/limits** pour DB et surveiller **rebuildReservedBandwidth**.
- **DNS cutover** : propagation → prévoir **TTL faible** 24–48h avant bascule.
- **Secrets** : fuite S3/DB = impact élevé → **SOPS/Vault** obligatoires + rotation périodique.

---

## 14) Check‑list de validation (prod)

- [ ] `StorageClass longhorn-db` en place (3 réplicas, xfs, expansion).
- [ ] MySQL StatefulSet OK, PVC 50 Gi bound, probes green, perf smoke (CRUD).
- [ ] XWiki up via Ingress TLS (LE prod), headers/redirects conformes.
- [ ] NetworkPolicies effectives (tests deny/allow).
- [ ] Backups XWiki + Longhorn tournent, **restore validé**.
- [ ] Dashboards Grafana OK (cluster, Longhorn, MySQL), alertes basiques actives.
- [ ] Runbooks à jour, plan rollback documenté.
- [ ] Renovate activé, images pinned.

---

## 15) Prochaines actions (opérationnelles)

1. Valider **décisions §9** (surtout version MySQL, FQDN, S3).
2. Générer rôles Ansible + templates .j2 (selon structure §11).
3. Déployer en **staging** complet, tester backup/restore.
4. Préparer **cutover** (TTL DNS, fenêtre, runbook), basculer prod.

---

_Contact: lOgO — GitOps-first. On reste exigeants & critiques._
""")

path = "/mnt/data/open4goods-k8s-xwiki-spec.md"
with open(path, "w") as f:
    f.write(md)

path
