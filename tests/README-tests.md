# README - Organisation et exécution des tests

## Structure des tests

Les tests sont organisés dans `tests/` :

-   `tests/smoke/` → Tests rapides de validation (smoke tests)
    -   `mysql/` : tests de connexion MySQL
    -   `ingress-nginx/` : tests de l'ingress
    -   `grafana/` : tests Grafana
    -   `longhorn/` : tests Longhorn (volumes, PVC, orphans)
    -   `namespace/` : tests liés aux politiques de namespaces
-   `tests/bdd-tests/` → Tests BDD (Behaviour Driven Development)
    -   `features/` : scénarios Gherkin
    -   `python/` : tests Pytest-BDD
    -   `go/` : tests Godog
    -   `node/` : tests Cucumber.js
    -   `yaml/` : jobs Kubernetes pour exécuter les tests
-   `tests/docker/` → Dockerfiles pour builder les images de tests

## Scripts disponibles

-   `scripts/apps/run-mysql-smoke.sh` → Lance un smoke test MySQL
-   `scripts/apps/run-mysql-bdd.sh` → Lance un test BDD MySQL
-   `scripts/apps/restart-mysql-pod.sh` → Redémarre le pod MySQL
-   `scripts/apps/load-local-image.sh` → Charge une image Docker locale
    dans containerd

## 

``` bash générer une image puis push sur le noeud
cd $HOME/nudger-gitops/tests
sudo docker build -t mysql-bdd:latest -f ./docker/Dockerfile .
docker images | grep mysql-bdd
$HOME/nudger-gitops/scripts/apps/load-local-image.sh mysql-bdd:latest
```

## Exemple : lancer un test BDD MySQL

``` bash
./scripts/apps/run-mysql-bdd.sh
```

Les résultats s'afficheront directement via les logs du job.

