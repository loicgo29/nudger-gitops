apiVersion: batch/v1
kind: CronJob
metadata:
  name: sync-xwiki-tls
  namespace: flux-system
spec:
  schedule: "0 */6 * * *"  # toutes les 6h
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: flux-reconciler   # doit avoir les droits sur les 2 namespaces
          containers:
          - name: sync-xwiki-tls
            image: bitnami/kubectl:1.31   # image légère avec kubectl
            command: ["/bin/sh", "-c"]
            args:
              - |
                set -e
                SRC_NS="ns-open4goods-recette"
                DST_NS="ns-open4goods-integration"
                SECRET_NAME="xwiki-tls"
                kubectl get secret -n "$SRC_NS" "$SECRET_NAME" -o yaml \
                  | sed "s/namespace: $SRC_NS/namespace: $DST_NS/" \
                  | kubectl apply -n "$DST_NS" -f -
          restartPolicy: OnFailure
