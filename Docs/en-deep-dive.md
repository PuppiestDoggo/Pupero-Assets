# Pupero — Deep technical dive

This document details the internals: architecture, data flows, APIs, background jobs, and ops considerations.

1. Architecture (services and responsibilities)
- Frontend (Pupero-LoginFrontEnd, Flask):
  - Serves HTML templates. Manages session cookies (HttpOnly), optional “remember me”, SameSite and Secure flags via env.
  - Calls internal APIs through API Manager (proxy). Implements the simple trade flow UI.
- API Manager (Pupero-APIManager, FastAPI):
  - A lightweight reverse‑proxy/gateway. Healthcheck at /healthz. Forwards routes to downstream services.
- Login Backend (Pupero-LoginBackend, FastAPI):
  - Endpoints for register/login, JWT token issuance/refresh, TOTP management, profile ops, account deletion.
  - Argon2 password hashing via passlib. JWT HS256 with configurable lifetimes. Optional TOTP using pyotp.
- Offers (Pupero-Offers, FastAPI):
  - CRUD for offers (list/create/my offers/details). Backed by SQLModel + MariaDB.
- Transactions/Ledger (inside repo, FastAPI):
  - Records internal transfers between users when trades are confirmed. Enqueues withdrawals to RabbitMQ.
- Wallet Manager (Pupero-MoneroWalletManager, FastAPI):
  - Talks to monero-wallet-rpc (transfer_split, get_balance, get_height, etc.).
  - Periodically polls RabbitMQ for withdraw jobs and executes on‑chain sends. Exposes /healthz and admin endpoints.
- RabbitMQ:
  - Queue for withdrawal jobs. Producer: Transactions. Consumer: Wallet Manager (interval or worker loop).
- Database (MariaDB):
  - Holds users, offers, balances, trades. SQLModel ORM used by Python services.
- Monero daemon (monerod) + monero-wallet-rpc:
  - monerod syncs blockchain; wallet‑rpc opens the Pupero wallet and accepts RPC calls (auth via MONERO_RPC_USER/PASSWORD).
- Optional monitoring (Pupero-Elastic):
  - Prometheus + Grafana for scraping and dashboards (not required for core functionality).
- Optional Matrix (Pupero-Matrix):
  - Example Synapse config for dev chat; not integrated into the core trade logic.

2. Networking and ports (dev overlay)
- Frontend: 5000
- API Manager: 8000
- Login: 8001
- Offers: 8002
- Transactions: 8003
- Wallet Manager: 8004
- RabbitMQ: 15672 (UI) + 5672 (AMQP internal)
- Monerod/Wallet RPC: from .env (e.g., MONEROD_RPC_PORT, WALLET_RPC_PORT)

3. Environment configuration (Pupero-Assets/.env)
- Database: DB_ROOT_PASSWORD, DB_NAME
- RabbitMQ: RABBITMQ_USER, RABBITMQ_PASSWORD, RABBITMQ_QUEUE
- Monero: MONEROD_ARGS ("--testnet" by default), MONEROD_P2P_PORT, MONEROD_RPC_PORT
- Wallet RPC: WALLET_RPC_PORT, MONERO_RPC_USER, MONERO_RPC_PASSWORD, MONERO_RPC_AUTH_SCHEME
- Wallet Manager:
  - RABBITMQ_POLL_INTERVAL_SECONDS (default 1800) — how often to scan queue for withdraws
- Sweeper:
  - SWEEP_INTERVAL_SECONDS, MIN_SWEEP_XMR — periodic on‑chain balance crediting to DB (if enabled)
- Frontend:
  - REMEMBER_ME_DAYS, SECURE_COOKIES, SESSION_COOKIE_SAMESITE

4. Data model (high level)
- Users: id, email, username, password_hash (argon2), 2FA secret (optional), profile fields.
- Offers: id, user_id (owner), side (buy/sell), price, amount, status, timestamps.
- Trades: id, buyer_id, seller_id, offer_id, state, confirmations timestamps.
- Balances/Ledger: per‑user internal XMR units for demo purposes (not actual on‑chain funds). Transfers recorded atomically.
- Withdrawals: queued messages with user_id, amount, address, idempotency key.

5. API surface (selected endpoints)
- Login Backend
  - POST /register — create user
  - POST /login — token pair (access+refresh)
  - POST /token/refresh — refresh access
  - GET /me — profile; PUT /me — update
  - POST /2fa/enable, POST /2fa/confirm, POST /2fa/disable
  - DELETE /me — delete account
- Offers
  - GET /offers — list; POST /offers — create
  - GET /offers/{id} — detail
  - GET /me/offers — current user’s offers
- Transactions
  - POST /transactions/transfer — internal transfer on trade confirmation
  - POST /withdraw — enqueue on‑chain withdrawal
  - GET /balances/{user_id} — balance lookup
- Wallet Manager
  - GET /healthz — readiness
  - POST /admin/withdraw/execute — internal handler for a queued withdraw (normally driven by consumer loop)

6. Sequence: trade and withdrawal
- Trade confirmation (happy path)
  1) Buyer clicks “Money sent” in Frontend; state stored client‑side/server‑side per flow.
  2) Seller clicks “I received money”.
  3) Frontend calls Transactions /transactions/transfer with seller->buyer amount.
  4) Transactions records ledger entry and updates balances atomically.
- Withdrawal
  1) User requests withdraw with address and amount in Frontend.
  2) Frontend calls Transactions /withdraw. Transactions enqueues a message to RabbitMQ with payload.
  3) Wallet Manager’s consumer loop (interval set by RABBITMQ_POLL_INTERVAL_SECONDS) reads message(s), validates, and calls monero-wallet-rpc transfer_split.
  4) On success, Wallet Manager marks the job done (and optionally records txids back to DB if enabled).

7. Security notes
- Hashing: Argon2id via passlib; never store plaintext passwords.
- Tokens: JWT HS256; keep JWT secret strong and out of VCS for real deployments.
- 2FA: TOTP (time‑based one‑time passwords). Recovery and backup codes are out of scope for this demo.
- Cookies: Set Secure=true and SameSite=Lax/Strict behind HTTPS in production.
- Secrets: .env kept in repo for demo; do not put real secrets. For production, mount secrets via environment or secret stores.
- Network: In production mode compose, only Frontend and API Manager are published; keep others internal and place a TLS reverse proxy in front.

8. Operations
- Startup order: monerod -> wallet‑rpc -> wallet manager; DB/RabbitMQ before dependent services; API Manager waits for health of core services.
- Health checks:
  - curl http://localhost:8000/healthz
  - curl http://localhost:8001/healthz
  - curl http://localhost:8002/healthz
  - curl http://localhost:8003/healthz
  - curl http://localhost:8004/healthz
  - curl http://localhost:5000/
- Logs: docker compose logs SERVICE_NAME; add -f to follow.
- Backups: dump DB from its container; copy wallet files and daemon data directories securely.
- Reset: docker compose … down -v (wipes volumes). For test/dev only.

9. Switching to mainnet
- In .env, remove --testnet from MONEROD_ARGS and open appropriate ports. Ensure you understand the security and legal implications. Protect wallet keys.

10. Troubleshooting
- Wallet not sending: ensure wallet‑rpc has the wallet open and authenticated; fund the wallet on the chosen network.
- Queue not consumed: verify RABBITMQ_* vars and that the consumer loop is running (Wallet Manager logs).
- API 5xx: look at the specific service logs; check DB migration/schema presence.
- Timeouts: Monero components may take time to sync; health endpoints will reflect readiness.

11. Extending the system
- Replace the simple trade flow with escrow or multisig.
- Add rate limits, audit logs, WebAuthn, or CAPTCHA on auth endpoints.
- Implement idempotency keys and deduplication on withdrawals in the DB layer.
- Add events/metrics to Prometheus and dashboards in Grafana.

This deep dive reflects the current repository layout and defaults. Consult service READMEs and code for the definitive behavior.