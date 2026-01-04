#!/usr/bin/env bash
set -euo pipefail

echo "Deleting kafka namespace..."
kubectl delete namespace kafka --ignore-not-found

echo "Deleting Strimzi CRDs..."
for crd in $(kubectl get crds -o name | grep strimzi || true); do
  kubectl delete "$crd"
done
