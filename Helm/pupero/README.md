Pupero Helm Chart

This chart packages the Pupero stack (Login, Offers, Transactions, API Manager, UI, Monero services, and Matrix/Element) for installation on a standard kubeadm Kubernetes cluster.

What’s included
- Core services: MariaDB, RabbitMQ, Login, Offers, Transactions, API Manager, Admin, Flask UI, Sweeper
- Monero stack: monerod (testnet), monero-wallet-rpc (from Secret-mounted wallet files), Wallet Manager API
- Matrix stack: Postgres (for Synapse), Synapse homeserver, Element Web with config
- A single Ingress for host pupero.replay.dog routing to Flask UI, API Manager, Matrix Synapse, and Element
- A minimal ingress-nginx controller (NodePort 30080/30443) to expose the Ingress when your cluster doesn’t already have one

Important defaults
- Persistence uses hostPath volumes on nodes:
  - /var/lib/pupero/db (MariaDB ~1Gi)
  - /var/lib/pupero/rabbitmq (RabbitMQ ~1Gi)
  - /var/lib/pupero/monero (Monero testnet ~10Gi)
  - /var/lib/pupero/synapse-db and /var/lib/pupero/synapse-data for Matrix
- Secrets include development defaults; change them before production.
- Element config points to https://pupero.replay.dog by default.

Install
1) Create the namespace and install the chart:
   helm install pupero ./Pupero-Assets/Helm/pupero -n pupero --create-namespace

2) Point DNS A record for pupero.replay.dog to the node that exposes NodePort 30080 (ingress-nginx). Alternatively, change the Ingress host in templates if you use a different hostname.

3) Provide real Monero wallet files (optional, for wallet-rpc):
   - Update templates/secrets.yaml (monero-wallet-files Secret) with your base64 files before installing
     or
   - After install, replace the Secret with kubectl apply -f <your secret yaml> -n pupero and restart pupero-wallet-rpc

Access
- UI (Flask): http://pupero.replay.dog/
- API Manager: http://pupero.replay.dog/api
- Matrix client API: http://pupero.replay.dog/_matrix
- Element Web: http://pupero.replay.dog/element/
- Monero Explorer: http://pupero.replay.dog/explorer/

Notes
- This chart mirrors the raw manifests under Pupero-Assets/k8s as close as possible to minimize surprises.
- Persistence is hostPath-based to avoid requiring a StorageClass; for production, replace hostPath with PVCs.
- The ingress-nginx controller is deployed within this release for convenience; if your cluster already has one, you can delete templates/ingress-nginx.yaml from the chart before installing or ignore it and keep only the Ingress.


Adding your Monero wallet files to the Secret (monero-wallet-files)
------------------------------------------------------------------
The pupero-wallet-rpc pod mounts a Secret named monero-wallet-files at /monero/wallets and expects three files:
- Pupero-Wallet (binary)
- Pupero-Wallet.keys (binary)
- Pupero-Wallet.address.txt (text)

Option A: Create/update the Secret directly from your files (recommended)
helm doesn't manage the content of kubectl-created Secrets. You can create/update it before or after installing the chart:

kubectl -n pupero create secret generic monero-wallet-files \
  --from-file=Pupero-Wallet=/path/to/Pupero-Wallet \
  --from-file=Pupero-Wallet.keys=/path/to/Pupero-Wallet.keys \
  --from-file=Pupero-Wallet.address.txt=/path/to/Pupero-Wallet.address.txt \
  --dry-run=client -o yaml | kubectl apply -f -

Then restart wallet-rpc to pick up the new files:

kubectl -n pupero rollout restart deployment pupero-wallet-rpc

Option B: Bake files into the chart’s Secret template (for labs/dev)
- Base64-encode your files and paste into templates/secrets.yaml under the monero-wallet-files Secret data: keys before helm install/upgrade.

base64 -w0 /path/to/Pupero-Wallet > Pupero-Wallet.b64
base64 -w0 /path/to/Pupero-Wallet.keys > Pupero-Wallet.keys.b64
base64 -w0 /path/to/Pupero-Wallet.address.txt > Pupero-Wallet.address.txt.b64

- Replace the empty strings with the base64 content and run:

helm upgrade --install pupero ./Pupero-Assets/Helm/pupero -n pupero --create-namespace

Notes
- The Secret keys must match exactly the filenames above.
- The wallet password is provided separately via Secret pupero-secrets (key: MONERO_WALLET_PASSWORD).


Ephemeral-storage evictions and limits
--------------------------------------
If kubelet evicts pods due to low ephemeral-storage, this chart includes mitigations:
- Lowered monero-wallet-rpc verbosity (--log-level=1) to reduce logs.
- Added ephemeral-storage requests/limits to:
  - ingress-nginx controller: request 100Mi, limit 1Gi
  - wallet-rpc: request 256Mi, limit 1.5Gi

You can tune these values in templates/ingress-nginx.yaml and templates/deployments-monero-matrix.yaml and then helm upgrade.
