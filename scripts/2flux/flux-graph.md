```mermaid
graph TD
  GitRepository_gitops --> Kustomization_infra-namespaces
  GitRepository_gitops --> Kustomization_ingress-nginx
  GitRepository_gitops --> Kustomization_kyverno-policies
  GitRepository_gitops --> Kustomization_lab-root
  GitRepository_gitops --> Kustomization_loki
  GitRepository_gitops --> Kustomization_observability
  GitRepository_gitops --> Kustomization_whoami
  HelmRepository_grafana --> HelmChart_logging-loki
  HelmRepository_grafana --> HelmChart_observability-grafana
  HelmRepository_prometheus-community --> HelmChart_observability-kube-prometheus-stack
  HelmRepository_victoria-metrics --> HelmChart_logging-victorialogs
  HelmRepository_victoria-metrics --> HelmChart_logging-victoriametrics
  HelmChart_grafana --> HelmRelease_grafana
  HelmChart_kube-prometheus-stack --> HelmRelease_kube-prometheus-stack
  HelmChart_loki --> HelmRelease_loki
  HelmChart_victorialogs --> HelmRelease_victorialogs
  HelmChart_victoriametrics --> HelmRelease_victoriametrics
```
