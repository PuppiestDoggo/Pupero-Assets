# Using Rook-Ceph as the storage backend

This guide shows how to deploy the Pupero Helm chart with Rook‑Ceph dynamic storage (StorageClass `rook-ceph-block`).

## 1) Install Rook-Ceph (operator and cluster)
Follow the official quickstart that matches your Kubernetes version. Example (latest as of writing – adjust versions to your environment):

- Install the operator:
  kubectl apply -f https://raw.githubusercontent.com/rook/rook/v1.14.9/deploy/examples/crds.yaml
  kubectl apply -f https://raw.githubusercontent.com/rook/rook/v1.14.9/deploy/examples/common.yaml
  kubectl apply -f https://raw.githubusercontent.com/rook/rook/v1.14.9/deploy/examples/operator.yaml

- Create a Ceph cluster (default example creates a viable dev cluster):
  kubectl apply -f https://raw.githubusercontent.com/rook/rook/v1.14.9/deploy/examples/cluster.yaml

Wait until the Ceph cluster is healthy:
  kubectl -n rook-ceph get pods

## 2) Create a StorageClass (rook-ceph-block)
If not already provided by your Rook installation, create the block StorageClass:

  kubectl apply -f https://raw.githubusercontent.com/rook/rook/v1.14.9/deploy/examples/csi/rbd/storageclass.yaml

Confirm it exists:
  kubectl get storageclass

You should see `rook-ceph-block` among the classes. Optionally set it as default:

  kubectl patch storageclass rook-ceph-block \
    -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

## 3) Configure the Pupero chart to use Rook
There are two ways:

- Global default (recommended): set a global StorageClass that all PVCs will use when a per-service storageClass is not specified.
- Per-service override: set `services.<name>.persistence.storageClass` explicitly.

This repo provides an example values file preconfigured for Rook:
- Pupero-Assets/HELM/pupero-values-rook.yaml

It sets:
- global.storageClass: rook-ceph-block
- Keeps monerod and walletRpc on hostPath by default (for performance and wallet locality). You can switch them to PVC by setting `useHostPath: false` and (optionally) a storageClass.

## 4) Install the chart with the Rook values

  helm upgrade --install pupero ./Pupero-Assets/HELM/pupero-chart \
    -n pupero --create-namespace \
    -f ./Pupero-Assets/HELM/pupero-values-rook.yaml

Verify PVCs bind to rook-ceph-block:

  kubectl -n pupero get pvc

You should see `Bound` status and `rook-ceph-block` as the STORAGECLASS for database, rabbitmq, matrix-db and matrix-synapse (unless you overrode them).

## 5) Notes and tips
- If PVCs are Pending, ensure the Rook cluster is healthy and the `rook-ceph-block` StorageClass exists.
- For production, size your PVCs according to your expected data growth (update `size` fields in values).
- monerod and wallet-rpc:
  - By default we mount host paths (configured via `global.paths.blockchainDir` and `global.paths.walletsDir`) for performance and easy data reuse across pods on the same node. If you prefer Ceph-backed volumes, set `services.monerod.persistence.useHostPath: false` and/or `services.walletRpc.persistence.useHostPath: false` and rely on the global storageClass.
- If your cluster uses a different StorageClass name, set `global.storageClass` to that name instead of `rook-ceph-block`.

## 6) Troubleshooting
- Describe a stuck PVC:

  kubectl -n pupero describe pvc <name>

- Check Rook/Ceph status:

  kubectl -n rook-ceph get pods
  kubectl -n rook-ceph logs deploy/rook-ceph-operator

- Ensure the CSI drivers are running (look for pods with `csi-rbdplugin` and provisioners).

## 7) How the chart applies the StorageClass
Templates will use the per-service storageClass if provided, otherwise fall back to `global.storageClass` when set. This is implemented for:
- database (MariaDB)
- rabbitmq
- matrix-db (Postgres for Synapse)
- matrix-synapse (homeserver data)
- monerod (only when not using hostPath)
- wallet-rpc (only when not using hostPath)

This makes it easy to switch the whole stack to Rook with a single value while retaining hostPath for components that benefit from it.
