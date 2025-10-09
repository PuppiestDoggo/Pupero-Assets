# Pupero — Technical overview (Accessible)

This document explains how to run Pupero and what each component does, without going too deep into internals.

What’s in the stack
- API Manager (port 8000): Single entrypoint that forwards requests to the right backend.
- Login Backend (port 8001): FastAPI service for auth (register, login, JWT, TOTP 2FA, profile, account deletion).
- Offers (port 8002): FastAPI service that stores and serves buy/sell offers.
- Transactions/Ledger (port 8003): FastAPI service that records internal balance transfers for trades and enqueues withdrawals.
- Monero Wallet Manager (port 8004): FastAPI service that talks to monero-wallet-rpc and executes on‑chain sends. Also consumes withdrawal jobs from RabbitMQ periodically.
- RabbitMQ (port 15672 for UI): Message queue for withdrawal jobs.
- Database (MariaDB): Stores users, offers, balances, and trades.
- Frontend (port 5000): Flask website for users.
- Monero daemon + wallet-rpc: Real Monero stack (defaults to testnet).
- Optional: Matrix/Element for chat (dev‑focused example), Prometheus/Grafana for metrics.

Running locally (development)
1) Build images (one‑time or when code changes):
   - cd Pupero-Assets
   - ./build_all_docker.sh
2) Copy environment file:
   - In Pupero-Assets, copy .env.example to .env and adjust if needed (testnet by default).
3) Start services (dev overlay publishes many ports):
   - docker compose -f docker-compose.base.yml -f docker-compose.dev.yml --env-file .env up -d
4) Open:
   - Frontend: http://localhost:5000
   - API Manager: http://localhost:8000/healthz
   - Login: http://localhost:8001/healthz
   - Offers: http://localhost:8002/healthz
   - Transactions: http://localhost:8003/healthz
   - Wallet Manager: http://localhost:8004/healthz
   - RabbitMQ UI: http://localhost:15672
5) Stop:
   - docker compose -f docker-compose.base.yml -f docker-compose.dev.yml down
   - Add -v to remove volumes (e.g., to reset DB).

Production‑like (no reverse proxy)
- docker compose -f docker-compose.base.yml -f docker-compose.prod.yml --env-file .env up -d
- This publishes only API Manager (8000) and Frontend (5000). Put your reverse proxy/TLS in front.

Environment variables (high‑level)
- Database: credentials and DB name.
- RabbitMQ: user, password, queue name.
- Monero: monerod args/ports, wallet‑rpc port and auth.
- Frontend: session and cookie options.
- Sweeper/Wallet Manager: intervals for scanning and withdrawal processing; min sweep amount.

Main user flows
- Register/Login: Frontend calls Login Backend via API Manager; credentials stored in DB with Argon2 hashing; optional 2FA with TOTP.
- Browse offers and trade: Frontend fetches offers; a simple two‑step confirmation flow is used for trades.
- Balance transfer: When both sides confirm, Transactions service records a transfer between user balances.
- Withdraw on‑chain: Transactions enqueues a withdrawal message; Wallet Manager periodically pulls from RabbitMQ and calls monero‑wallet‑rpc to send.

Monero testnet vs mainnet
- Default: testnet (safe for experiments). Data in Pupero-Assets/.bitmonero and wallets in Pupero-Assets/wallets.
- Switch to mainnet: edit MONEROD_ARGS in .env (remove --testnet) and adjust network/firewall as needed.

Backups and data
- Database volume: db_data (dump from inside the DB container when needed).
- Monero data: Pupero-Assets/.bitmonero and Pupero-Assets/wallets — keep secrets safe if you ever use real funds.

Troubleshooting basics
- Check health endpoints.
- docker compose logs SERVICE_NAME for errors.
- Ensure monerod is fully started before wallet‑rpc and wallet manager.

That’s all you need to understand and run Pupero day‑to‑day. For deep internals, see the “Deep dive” document.