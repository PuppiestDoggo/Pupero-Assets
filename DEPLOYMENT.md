# Deployment (Docker Compose)

This guide describes running Pupero with Docker Compose in two modes: development and production‑like (no reverse proxy).

## Prerequisites
- Docker and Docker Compose Plugin
- Built images (./build_all_docker.sh)

## Configure environment
- cd Pupero-Assets
- cp .env.example .env
- Edit .env to your needs (kept in repo per current policy; do not place real secrets).

## Development
- docker compose -f docker-compose.base.yml -f docker-compose.dev.yml --env-file .env up -d
- docker compose -f docker-compose.base.yml -f docker-compose.dev.yml ps
- docker compose -f docker-compose.base.yml -f docker-compose.dev.yml logs -f

Published ports (dev):
- API Manager: 8000
- Login: 8001
- Offers: 8002
- Transactions: 8003
- Wallet Manager: 8004
- Frontend (Flask): 5000
- RabbitMQ: 5672, 15672 (UI)
- Monerod RPC: ${MONEROD_RPC_PORT}

## Production‑like (no reverse proxy in stack)
- docker compose -f docker-compose.base.yml -f docker-compose.prod.yml --env-file .env up -d

Published ports (prod overlay):
- API Manager: 8000
- Frontend: 5000

You can add your own reverse proxy for TLS and domain routing outside this stack.

## Switching networks (testnet/mainnet)
- Testnet default: MONEROD_ARGS=--testnet (in .env)
- Mainnet: set MONEROD_ARGS to an empty value or mainnet flags, and adjust port mappings as needed in dev overlay.

## Health and readiness
- All core services expose /healthz (or equivalent). Compose healthchecks ensure proper startup order, especially monerod -> wallet-rpc -> wallet manager.

## Data locations
- Database: volume db_data
- Monero daemon data: Pupero-Assets/.bitmonero
- Wallet files: Pupero-Assets/wallets

## Lifecycle
- Stop: docker compose -f docker-compose.base.yml -f <overlay>.yml down
- Reset (wipe DB): add -v to down
- Rebuild images after code changes: ./build_all_docker.sh

## Troubleshooting
- Check health: curl http://localhost:8000/healthz (and others listed in README)
- Wallet RPC auth errors: verify MONERO_RPC_USER/MONERO_RPC_PASSWORD in .env
- Monerod permission errors: ensure .bitmonero exists and is writable; SELinux may require :z mount label (already included).
- Wallet file not found: ensure Pupero-Assets/wallets has Pupero-Wallet and related files (address/keys).
