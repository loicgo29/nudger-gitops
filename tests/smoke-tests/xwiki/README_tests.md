
# 🧪 Tests XWiki

Ce dossier contient les **smoke-tests** et **BDD-tests** pour valider le déploiement de XWiki (17.3.0).

---

## 🚀 1. Smoke Test (HTTP 200)

- Vérifie que l’URL d’accueil de XWiki répond (`/` → HTTP 200).
- Implémenté dans :
  - Script : [`xwiki-smoke.sh`](./xwiki-smoke.sh)
  - Workflow : [`.github/workflows/xwiki-smoke.yml`](../../../.github/workflows/xwiki-smoke.yml)

### Lancement manuel

```bash
chmod +x tests/smoke-tests/xwiki/xwiki-smoke.sh
tests/smoke-tests/xwiki/xwiki-smoke.sh
```

---

## 🗄️ 2. BDD Test (Persistance)

- Vérifie que **les données XWiki persistent** après suppression/recréation du pod.
- Étapes :
  1. Création d’une page de test dans XWiki.
  2. Suppression du pod `xwiki-0`.
  3. Vérification que la page existe toujours.
- Implémenté dans :
  - Script : [`xwiki-bdd.sh`](./xwiki-bdd.sh)
  - Workflow : [`.github/workflows/xwiki-bdd.yml`](../../../.github/workflows/xwiki-bdd.yml)

### Lancement manuel

```bash
chmod +x tests/smoke-tests/xwiki/xwiki-bdd.sh
tests/smoke-tests/xwiki/xwiki-bdd.sh
```

---

## ⚙️ 3. Pré-requis

- Namespace : `ns-open4goods-recette`
- Service : `xwiki-svc` (ClusterIP 8080)
- Ingress : `xwiki.nudger.logo-solutions.fr`
- Secrets :
  - `mysql-xwiki-secret` (DB user & password)
- `KUBECONFIG` doit pointer vers le cluster :
  ```bash
  export KUBECONFIG=$PWD/kubeconfig-ci.yaml
  ```

---

## 📂 Arborescence

```
tests/smoke-tests/xwiki/
├── xwiki-smoke.sh      # test HTTP simple
├── xwiki-bdd.sh        # test persistance BDD
└── README-tests.md     # ce fichier
```

---

✅ **Definition of Done (DoD)** :
- Smoke test = HTTP 200 OK.
- BDD test = persistance validée après suppression du pod.
- Les workflows GitHub Actions passent sans erreur.

