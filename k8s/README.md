Pupero Kubernetes Manifests (kubeadm, 3 nodes)

This directory contains a minimal set of Kubernetes manifests to deploy the Pupero stack on a standard kubeadm cluster. It includes:
- Core services: MariaDB, RabbitMQ, API Manager, Login, Offers, Transactions, Admin, Flask UI
- Monero stack: monerod (testnet), monero-wallet-rpc (using wallet files from a Secret), WalletManager API
- Matrix stack: Postgres (for Synapse), Synapse homeserver, Element web client
- Ingress-NGINX controller (NodePort) and a single Ingress for host pupero.replay.dog

IMPORTANT: hostPath storage
- To keep it simple without a cluster StorageClass, these manifests use hostPath for stateful data:
  /var/lib/pupero/db          → MariaDB (≈1Gi)
  /var/lib/pupero/rabbitmq    → RabbitMQ (≈1Gi)
  /var/lib/pupero/monero      → Monero blockchain (≈10Gi testnet)
  /var/lib/pupero/synapse-db  → Postgres data
  /var/lib/pupero/synapse-data→ Synapse config/state
- hostPath data lives on the Kubernetes node where each Pod is scheduled. In a 3‑node cluster, ensure those Pods are scheduled on the same node across restarts, or consider migrating to a proper StorageClass (e.g., rook-ceph) later.
- For better reliability, add nodeSelector/affinity to pin stateful Pods to a chosen node.

Prerequisites
- DNS A record: pupero.replay.dog → any node IP hosting the ingress-nginx NodePort service (or a load balancer/VIP you manage).
- Open firewall: TCP 30080 (HTTP) and optionally 30443 (HTTPS) on the chosen node(s) for Ingress.
- Wallet files: provide your Monero wallet files via Secret before starting wallet-rpc.

Files
- namespace.yaml        → Namespace pupero
- configmap.yaml        → Non-sensitive defaults
- secrets.yaml          → DB root password, RabbitMQ creds, Matrix secret, Monero RPC creds, and monero-wallet-files secret (placeholders)
- deployments-core.yaml → Deployments for db, rabbitmq, login, offers, transactions, api-manager, admin, flask, sweeper
- deployments-monero-matrix.yaml → Deployments for monerod, wallet-rpc, walletmanager, matrix-db, matrix-synapse, element
- services.yaml         → ClusterIP Services for all components
- ingress-nginx.yaml    → Minimal ingress-nginx controller (NodePort 30080/30443)
- ingress.yaml          → Ingress for pupero.replay.dog routing: / (Flask UI), /api (API Manager), /_matrix (Synapse), /element (Element)

Quick start
1) Create namespace and base config/secrets
   kubectl apply -f namespace.yaml
   kubectl apply -f configmap.yaml
   # Edit secrets.yaml to include your real passwords and wallet files (monero-wallet-files). Then:
   kubectl apply -f secrets.yaml

2) Install ingress-nginx (controller)
   kubectl apply -f ingress-nginx.yaml
   # Wait for the Deployment to be ready, then ensure Service ingress-nginx/ingress-nginx-controller has NodePorts 30080/30443

3) Deploy stateful dependencies first
   kubectl apply -f deployments-core.yaml -n pupero
   kubectl apply -f deployments-monero-matrix.yaml -n pupero
   kubectl apply -f services.yaml -n pupero

4) Create Ingress
   kubectl apply -f ingress.yaml -n pupero

5) DNS and access
   - Point pupero.replay.dog to the node that exposes the Ingress NodePort.
   - Access UI at: http://pupero.replay.dog/
   - API Manager at: http://pupero.replay.dog/api (used server-side by the UI)
   - Element at: http://pupero.replay.dog/element
   - Matrix client endpoints: http://pupero.replay.dog/_matrix
   - Monero Explorer at: http://pupero.replay.dog/explorer

Notes
- Matrix server name is configured via ConfigMap (MATRIX_SERVER_NAME) and defaults to "localhost". Change to your FQDN if needed.
- For TLS, bring your own termination (e.g., MetalLB + cert-manager) or adapt ingress-nginx Service/Ingress to type LoadBalancer and add tls: in ingress.yaml.
- If you prefer PVCs: replace hostPath volumes with PersistentVolumeClaims (with a default StorageClass) and configure requested sizes (DB 1Gi, Monero 10Gi, RabbitMQ 1Gi).
- To pin stateful pods to a specific node: add nodeSelector like
    spec: { nodeSelector: { kubernetes.io/hostname: your-node-name } }
  under the Pod template of those Deployments.

Uninstall
  kubectl delete -f ingress.yaml -n pupero
  kubectl delete -f services.yaml -n pupero
  kubectl delete -f deployments-monero-matrix.yaml -n pupero
  kubectl delete -f deployments-core.yaml -n pupero
  kubectl delete -f ingress-nginx.yaml
  kubectl delete -f secrets.yaml -n pupero
  kubectl delete -f configmap.yaml -n pupero
  kubectl delete -f namespace.yaml




Adding your Monero wallet files to the Secret (monero-wallet-files)
------------------------------------------------------------------
The monero-wallet-rpc pod mounts a Secret named monero-wallet-files at /monero/wallets and expects three files:
- Pupero-Wallet (binary)
- Pupero-Wallet.keys (binary)
- Pupero-Wallet.address.txt (text)

There are two easy ways to populate this Secret.

Option A: Create/update the Secret directly from your files (recommended)
- Replace the /path/to/... with the real paths to your files on your machine.

kubectl -n pupero create secret generic monero-wallet-files \
  --from-file=Pupero-Wallet=/path/to/Pupero-Wallet \
  --from-file=Pupero-Wallet.keys=/path/to/Pupero-Wallet.keys \
  --from-file=Pupero-Wallet.address.txt=/path/to/Pupero-Wallet.address.txt \
  --dry-run=client -o yaml | kubectl apply -f -

Then restart the wallet-rpc deployment to pick up the new files:

kubectl -n pupero rollout restart deployment pupero-wallet-rpc

Option B: Edit secrets.yaml with base64 and apply
- Base64-encode your files and paste into Pupero-Assets/k8s/secrets.yaml under the monero-wallet-files Secret.

base64 -w0 /path/to/Pupero-Wallet > Pupero-Wallet.b64
base64 -w0 /path/to/Pupero-Wallet.keys > Pupero-Wallet.keys.b64
base64 -w0 /path/to/Pupero-Wallet.address.txt > Pupero-Wallet.address.txt.b64

- Paste the contents into the data: fields, then:

kubectl apply -f Pupero-Assets/k8s/secrets.yaml -n pupero

- Restart wallet-rpc as shown above.

Notes
- The Secret keys must match exactly the filenames expected by the manifest.
- The wallet password is provided separately in Secret pupero-secrets (key: MONERO_WALLET_PASSWORD).


About ephemeral-storage evictions and limits
-------------------------------------------
If you see messages like:
  Warning  Evicted  kubelet  The node was low on resource: ephemeral-storage ...

the node’s disk space for container writable layers/logs is low. This repo includes mitigations:
- Lowered monero-wallet-rpc verbosity (--log-level=1) to reduce log volume.
- Added resources.requests/limits for ephemeral-storage:
  - ingress-nginx controller: request 100Mi, limit 1Gi
  - wallet-rpc: request 256Mi, limit 1.5Gi

You can tune these values by editing:
- Pupero-Assets/k8s/ingress-nginx.yaml (controller container)
- Pupero-Assets/k8s/deployments-monero-matrix.yaml (pupero-wallet-rpc container)

Operational tips to free space on nodes
- Prune unused images: sudo crictl image prune (containerd) or docker image prune (Docker)
- Rotate/prune container logs under /var/log/containers and /var/log/pods
- Vacuum systemd journal: sudo journalctl --vacuum-size=200M


Ingress-NGINX CrashLoopBackOff
------------------------------
If the ingress controller repeatedly restarts and readiness on :10254 fails, ensure you have applied Pupero-Assets/k8s/ingress-nginx.yaml from this repo. The controller container now runs as non-root and adds the NET_BIND_SERVICE capability so it can bind ports 80/443 in the container. After applying, check:

kubectl -n ingress-nginx get pods -l app.kubernetes.io/name=ingress-nginx
kubectl -n ingress-nginx logs deploy/ingress-nginx-controller

