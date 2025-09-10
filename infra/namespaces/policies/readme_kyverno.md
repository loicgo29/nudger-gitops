
# ClusterPolicy Kyverno — `nudger-security-guardrails`

Cette note résume les règles mises en place par la policy Kyverno `nudger-security-guardrails`.

---

## Contexte

- Mode : `validationFailureAction: Enforce` → refus en cas de non-conformité.
- Portée : ressources de type **Pod**.
- `background: false` + `skipBackgroundRequests: true` → agit uniquement **à l’admission** (pas rétroactif sur les Pods existants).

---

## Règles principales

### 1. Exceptions nécessitant une justification
- Si un Pod a l’un des labels :
  - `security.nudger/allow-rw-rootfs: "true"`
  - `security.nudger/allow-init-root: "true"`
- Alors il doit avoir l’annotation :
  - `security.nudger/justification: "<texte non vide>"`
- Sinon : refus avec le message  
  *« Exception sécurité sans justification : ajoutez annotation security.nudger/justification. »*

---

### 2. Durcissement automatique (opt-in)
- Si le Pod a le label `security.nudger/auto-harden: "true"`, Kyverno applique automatiquement :
  - `spec.automountServiceAccountToken: false`
  - Pour chaque container :
    - `allowPrivilegeEscalation: false`
    - `capabilities.drop: ["ALL"]`
    - `readOnlyRootFilesystem: true`
    - `runAsNonRoot: true`
  - Au niveau Pod :
    - `seccompProfile: RuntimeDefault`
    - `fsGroup: 101`

---

### 3. Root filesystem en lecture seule (opt-out possible)
- Par défaut, Kyverno applique `readOnlyRootFilesystem: true` sur tous les containers.
- Exception si le label `security.nudger/allow-rw-rootfs: "true"` est présent (avec justification obligatoire).

---

### 4. Init container root (opt-in + justification)
- Si le Pod a `security.nudger/allow-init-root: "true"`, Kyverno injecte un **initContainer** `nudger-perms` :
  - Image : `busybox:1.36`
  - S’exécute en root (`runAsUser: 0`)
  - Prépare les répertoires `/var/cache/nginx`, `/var/run`, `/var/log/nginx`  
    (création, `chown 101:101`, `chmod 0775`).

---

## Exemples d’utilisation

### a) Durcir un Pod automatiquement
```yaml
metadata:
  labels:
    security.nudger/auto-harden: "true"
```

### b) Autoriser un rootfs en écriture (opt-out)
```yaml
metadata:
  labels:
    security.nudger/allow-rw-rootfs: "true"
  annotations:
    security.nudger/justification: "Besoin d'écriture /tmp pendant migration"
```

### c) Injecter l’init root pour préparer les volumes
```yaml
metadata:
  labels:
    security.nudger/allow-init-root: "true"
  annotations:
    security.nudger/justification: "Nginx nécessite /var/log & /var/run"
```

---

## Différenciation avec Pod Security Admission (PSA)
- Les messages **« violates PodSecurity restricted:latest »** proviennent du **PSA Kubernetes**.
- Les mutations automatiques (ajout de `readOnlyRootFilesystem`, `drop: ALL`, etc.) proviennent de **Kyverno**.

---

## Bonnes pratiques
- Toujours monter les répertoires nécessaires (`/tmp`, `/var/run`, `/var/log/nginx`, `/var/cache/nginx`) en `emptyDir` si rootfs est RO.
- Utiliser des annotations de justification pour tout Pod nécessitant une exception.


