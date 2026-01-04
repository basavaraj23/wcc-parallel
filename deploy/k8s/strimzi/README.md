# Strimzi Operator Overrides

Apply these manifests after the upstream Strimzi installation to ensure the operator runs in the `kafka` namespace while watching `wcc-1-dev`, and to grant it leader election permissions.

```bash
kubectl apply -n kafka -f deploy/k8s/strimzi/060-RBAC-strimzi.yaml
kubectl apply -n kafka -f deploy/k8s/strimzi/050-Deployment-strimzi-cluster-operator.yaml
```
