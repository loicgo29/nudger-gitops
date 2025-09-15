kubectl -n observability get ingress
kubectl -n observability get svc grafana
kubectl -n observability get pods -l app.kubernetes.io/name=grafana -o wide
