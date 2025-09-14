#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

docker build -t pupero-api-manager -f APIManager/Dockerfile .
docker build -t pupero-login -f Login/Dockerfile .
docker build -t pupero-offers -f Offers/Dockerfile .
docker build -t pupero-transactions -f Transactions/Dockerfile .
docker build -t pupero-monero-wallet -f MoneroWalletManager/Dockerfile .
docker build -t pupero-database -f DB/Dockerfile .
docker build -t pupero-flask -f FlaskProject/Dockerfile .
docker build -t pupero-sweeper -f Sweeper/Dockerfile .

echo "All images built."
