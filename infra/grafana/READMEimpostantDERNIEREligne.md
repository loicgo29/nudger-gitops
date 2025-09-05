helm upgrade --install loki grafana/loki-stack   -n logging   --set loki.image.tag=2.9.3

# Procédure de Setup Grafana + Loki

Ce guide permet de déployer une stack **Grafana + Loki** fonctionnelle sur une nouvelle VM Kubernetes.

---

## 1. Installer Loki (Helm Chart)

```bash
helm upgrade --install loki grafana/loki-stack -n logging --create-namespace   --set loki.image.tag=2.9.3
```
⚠️ Important : forcer la version de Loki (`2.9.3`) pour garantir compatibilité.

---

## 2. Vérifier Loki

```bash
kubectl -n logging get pods
kubectl -n logging get svc
kubectl -n logging logs statefulset/loki --tail=50
```

Tester la santé :

```bash
kubectl -n logging exec -it loki-0 -- wget -qO- http://localhost:3100/ready
```

---

## 3. Installer Grafana

```bash
helm upgrade --install grafana grafana/grafana -n grafana --create-namespace
```

Récupérer le mot de passe admin :

```bash
kubectl get secret -n grafana grafana -o jsonpath="{.data.admin-password}" | base64 -d; echo
```

---

## 4. Configurer Ingress Grafana

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-ingress
  namespace: grafana
spec:
  ingressClassName: nginx
  rules:
  - host: grafana.<ton-ip>.nip.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: grafana
            port:
              number: 80
```

---

## 5. Provisionner Datasource Loki

```bash
kubectl -n grafana create configmap loki-ds --from-literal=datasources.yaml='apiVersion: 1
datasources:
  - name: loki
    type: loki
    access: proxy
    url: http://loki.logging.svc.cluster.local:3100
    isDefault: true
    jsonData:
      maxLines: 1000
' --dry-run=client -o yaml | kubectl apply -f -
```

Monter le ConfigMap dans Grafana :

```bash
kubectl -n grafana patch deploy grafana --type=json -p='[
  {"op":"add","path":"/spec/template/spec/volumes/-","value":{
    "name":"ds","configMap":{"name":"loki-ds","items":[{"key":"datasources.yaml","path":"loki.yaml"}]}}
  },
  {"op":"add","path":"/spec/template/spec/containers/0/volumeMounts/-","value":{
    "name":"ds","mountPath":"/etc/grafana/provisioning/datasources/loki.yaml","subPath":"loki.yaml"}}
]'
kubectl -n grafana rollout status deploy/grafana
```

---

## 6. Vérifications

Lister les datasources connues par Grafana :

```bash
kubectl -n grafana exec -it deploy/grafana --   curl -s -u admin:$GF_SECURITY_ADMIN_PASSWORD http://localhost:3000/api/datasources
```

Test Loki depuis Grafana :

```bash
kubectl -n grafana exec -it deploy/grafana --   curl -sG --data-urlencode 'query={job="varlogs"}'   http://loki.logging.svc.cluster.local:3100/loki/api/v1/query
```

---

✅ Tu as maintenant Grafana + Loki fonctionnels et reliés.  
La prochaine fois : exécute ces étapes dans l’ordre et tu éviteras les erreurs de configuration.

