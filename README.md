
---

# WCC Kind Cluster — Argo CD Deployment Guide

This document provides **step-by-step instructions** to provision and manage the following operators on a **Kind (Kubernetes-in-Docker)** cluster using **Argo CD** and **Helm**:

- **CloudNativePG (PostgreSQL Operator)**
- **Kafka Operator (Strimzi)**
- **Redis Operator (Bitnami)**
- Managed via **Argo CD** using a Helm chart (`chip-applications`)

---

## Prerequisites

Ensure the following are installed locally:

- [Kind](https://kind.sigs.k8s.io/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/)
- [Argo CD CLI](https://argo-cd.readthedocs.io/en/stable/cli_installation/)

---

## Step 1: Create Kind Cluster

If an old cluster exists, delete it first:

```bash
kind delete cluster --name wcc-parallel
````

Create a new cluster:

```bash
kind create cluster --name wcc-parallel
```

---

## Step 2: Create Namespaces

Create required namespaces:

```bash
kubectl create ns wcc-1-dev || true
kubectl create ns kafka || true
kubectl create namespace argo-1-stg
```

---

## Step 2.5: Create Local Secrets

Seed the datastore secrets in the workload namespace (`wcc-1-dev`) before Argo CD starts reconciling those charts:

```bash
kubectl -n wcc-1-dev create secret generic wcc-redis-auth \\
  --from-literal=redis-password=redis123#
kubectl -n wcc-1-dev create secret generic wcc-postgresql-auth \\
  --from-literal=username=wcc_app \\
  --from-literal=password=postgresql123#
```

Feel free to replace the sample credentials (update them to stronger values before sharing code or pushing to remote repos); keep the secret names and keys so the Kind value files continue to resolve them.

---

## Step 2.6: Import Stack Settings Secret

Traefik and certificate templates expect a `stack-settings` secret in `wcc-1-dev`. In production this secret is sourced from AWS Systems Manager Parameter Store at `/wcc-dev-1/stack_settings` (region **eu-west-1**, i.e., Europe/Ireland). Pull it locally and create the matching secret before enabling ingress:

```bash
aws ssm get-parameter \
  --name /wcc-dev-1/stack_settings \
  --region eu-west-1 \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text > /tmp/stack-settings.json

kubectl -n wcc-1-dev create secret generic stack-settings \
  --from-literal=cluster_env=$(jq -r '.cluster_env' /tmp/stack-settings.json) \
  --from-literal=stack_domain_name=$(jq -r '.stack_domain_name' /tmp/stack-settings.json)
```

> Adjust the literal flags if your parameter stores additional keys. Delete `/tmp/stack-settings.json` afterwards.

---

## Step 3: Install Strimzi Kafka Operator (v0.48.0)

Create the operator namespace (already created above, safe to repeat) and apply the pinned manifest:

```bash
kubectl create ns kafka || true
curl -L https://github.com/strimzi/strimzi-kafka-operator/releases/download/0.48.0/strimzi-cluster-operator-0.48.0.yaml \
  | sed 's/namespace: .*/namespace: kafka/' \
  | kubectl apply -f -
kubectl -n kafka rollout status deploy/strimzi-cluster-operator
```

> The `sed` command scopes the cluster-operator deployment to namespace `kafka`. Update this namespace if you prefer a different target.

---

## Step 4: Install Argo CD

Apply the official Argo CD manifest:

```bash
kubectl apply -n argo-1-stg -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.1.9/manifests/install.yaml
```

Wait for the Argo CD server to be ready:

```bash
kubectl -n argo-1-stg rollout status deploy/argocd-server
```

---

## Step 5: Deploy Kafka, Redis, and PostgreSQL via Helm

`build/helm/chip-applications` is a thin chart that renders an Argo CD `Application`. Install one release per datastore (Kafka, Redis, PostgreSQL) and feed it the matching value files under `deploy/k8s/chip`. Those value files define which Git repository/branch Argo CD syncs (defaults to this GitHub repo on `main`) plus which workload values under `deploy/k8s/apps` should be used when templating the Helm charts in `build/helm/…`.

Install the three data stores into the Kind environment:

```bash
# Kafka (Strimzi cluster + topic)
helm upgrade --install wcc-kafka-cluster ./build/helm/chip-applications \
  -n argo-1-stg \
  -f deploy/k8s/chip/kafka-cluster/values.yaml

# Redis (Bitnami image with master/replica statefulsets)
helm upgrade --install wcc-redis-cluster ./build/helm/chip-applications \
  -n argo-1-stg \
  -f deploy/k8s/chip/redis-cluster/values.yaml

# PostgreSQL (CloudNativePG cluster)
helm upgrade --install wcc-postgresql-cluster ./build/helm/chip-applications \
  -n argo-1-stg \
  -f deploy/k8s/chip/postgresql-cluster/values.yaml
```

The bundled Kafka chart (`build/helm/kafka-cluster`) targets Strimzi 0.48.0 with the default ZooKeeper ensemble and pins Kafka 3.8.1 so it stays on the 3.8.x line while remaining compatible with Kubernetes 1.33.

> Make sure Argo CD can reach the GitHub repo first, for example:
>```bash
>argocd repo add git@github.com:basavaraj23/wcc-parallel.git \
>  --name wcc-parallel --ssh-private-key-path ~/.ssh/id_ed25519_bkittali
>```
>Once added, Argo CD tracks branch `main` by default (override with `--set sources.helm[0].targetRevision=<branch>` while installing the chart).

If you manage repository credentials via `kubectl`, create the secret instead of using the Argo CD CLI:
```bash
kubectl create secret generic repo-github-wcc \
  --from-literal=url=git@github.com:basavaraj23/wcc-parallel.git \
  --from-literal=name=wcc-parallel \
  --from-file=sshPrivateKey=~/.ssh/id_ed25519_bkittali \
  -n argo-1-stg
kubectl label secret repo-github-wcc argocd.argoproj.io/secret-type=repository -n argo-1-stg
```

With the secret in place, Argo CD pulls chart content from branch `main`.

---

## Step 6: Retrieve Argo CD Admin Password

Get the auto-generated admin password:

```bash
kubectl -n argo-1-stg get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo
```

Example output:

```
7vgxzuaryY-LtqhV
```

---

## Step 7: Access Argo CD UI

Port-forward the Argo CD server service:

```bash
kubectl -n argo-1-stg port-forward svc/argocd-server 8080:443
```

Access the dashboard at:

[https://localhost:8080](https://localhost:8080)

Log in via CLI (run in a second terminal after the port-forward starts):

```bash
argocd login localhost:8080 --username admin --password <initial-password> --insecure
```

Replace `<initial-password>` with the value from the previous step or inline the command:

```bash
argocd login localhost:8080 --username admin \
  --password "$(kubectl -n argo-1-stg get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)" \
  --insecure
```

Login credentials:

* **Username:** `admin`
* **Password:** (use the value retrieved above)

---

## Step 8: Verify Application Deployments

List all Argo CD applications:

```bash
kubectl -n argo-1-stg get applications.argoproj.io
```

Check specific operators:

```bash
kubectl -n argo-1-stg get applications.argoproj.io | grep -i kafka
kubectl -n argo-1-stg describe application strimzi-operator
kubectl -n argo-1-stg describe application cloudnativepg-operator
kubectl -n argo-1-stg describe application redis
kubectl -n argo-1-stg describe application kafka-cluster
```

---

## Verification

---

## Step 9: Run Service Smoke Tests (Optional)

Track the Argo CD application first:

```bash
kubectl -n argo-1-stg get applications.argoproj.io service-tests
kubectl -n argo-1-stg describe application service-tests
```

Prefer the UI? Port-forward Argo CD and open https://localhost:8080, then inspect the `service-tests` tile.

The umbrella chart now creates a `service-tests` Argo CD application that provisions short-lived workloads to exercise Redis, PostgreSQL, and Kafka.

1. Wait until the `service-tests` application appears in Argo CD and finishes syncing (it is set to auto-sync).
2. Check the verification jobs with `kubectl get jobs -A | grep smoketest`.
3. Inspect the job logs for additional detail, for example `kubectl -n wcc-1-dev logs job/wcc-pg-test-smoketest` or `kubectl -n wcc-1-dev logs job/wcc-kafka-smoketest`.

What gets deployed:
- A CloudNativePG `Cluster` named `wcc-pg-test` (namespace `wcc-1-dev`) and a job that creates a table, inserts a row, and queries it back.
- A Redis smoke-test job that authenticates with the Bitnami release, writes a key, and reads it back.
- A Strimzi-backed topic (`wcc-test-topic`), SCRAM user, and job that produces and consumes a unique message.

Disable the tests by setting `serviceTests.enabled=false` (or by removing the application in Argo CD) once you are done.

---


After successful synchronization in Argo CD UI, verify operator pods:

```bash
kubectl get pods -A | grep -E "cnpg|strimzi|redis"
```

Expected namespaces:

* `cnpg-system` → CloudNativePG Operator
* `kafka` → Strimzi Operator
* `wcc-1-dev` → Redis Operator and application workloads

---

## Cleanup

To remove everything:

```bash
kind delete cluster --name wcc-parallel
```

---

## Notes

* `chip-applications` chart should contain Helm subcharts or Argo CD `Application` manifests for each operator.
* For production or CI/CD use, sync policies can be automated with:

  ```yaml
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
  ```

---

### References

* [Argo CD Docs](https://argo-cd.readthedocs.io/)
* [CloudNativePG Operator](https://cloudnative-pg.io/)
* [Strimzi Kafka Operator](https://strimzi.io/)
* [Bitnami Redis Helm Chart](https://bitnami.com/stack/redis/helm)

---

**Author:** Garden City Games — DevOps
**Cluster Name:** `wcc-parallel`
**Last Updated:** October 2025

```

---
