#!/usr/bin/env bash
set -euo pipefail
# Start all services each in its own venv and terminal/background
# Adjust ports via .envs where applicable

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

start_in_dir() {
  local dir="$1"; shift
  local cmd="$*"
  (cd "$dir" && if [ -d .venv ]; then source .venv/bin/activate; fi; echo "Starting $dir: $cmd"; eval "$cmd") &
}

# API Manager (8000)
start_in_dir APIManager "uvicorn app.main:app --app-dir APIManager --host 0.0.0.0 --port \
  \${API_MANAGER_PORT:-8000}"

# Login (8001)
start_in_dir Login "uvicorn app.main:app --app-dir Login --host 0.0.0.0 --port \${LOGIN_PORT:-8001}"

# Offers (8002)
start_in_dir Offers "uvicorn app.main:app --app-dir Offers --host 0.0.0.0 --port \${OFFERS_PORT:-8002}"

# Transactions (8003)
start_in_dir Transactions "uvicorn app.main:app --app-dir Transactions --host 0.0.0.0 --port \${TRANSACTIONS_PORT:-8003}"

# MoneroWalletManager (8004)
start_in_dir MoneroWalletManager "uvicorn app.main:app --app-dir MoneroWalletManager --host 0.0.0.0 --port \${MONERO_WALLET_MANAGER_PORT:-8004}"

# Flask Frontend (5000)
start_in_dir FlaskProject "flask --app FlaskProject/app.py run --host 0.0.0.0 --port \${PORT:-5000}"

wait
