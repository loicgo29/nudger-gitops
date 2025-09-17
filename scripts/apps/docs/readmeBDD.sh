cdo
cd tests
sudo docker build -t mysql-bdd:latest -f ./docker/Dockerfile .
docker images | grep mysql-bdd
./scripts/apps/load-local-image.sh mysql-bdd:latest
Vérifier que l’image est bien dispo sur le nœud
sudo ctr -n k8s.io images ls | grep mysql-bdd
relancer BDD
kubectl -n ns-open4goods-recette delete job mysql-bdd --ignore-not-found
kubectl -n ns-open4goods-recette apply -f tests/bdd-tests/yaml/job-mysql-bdd.yaml
suivre les logs
kubectl -n ns-open4goods-recette logs -f job/mysql-bdd
