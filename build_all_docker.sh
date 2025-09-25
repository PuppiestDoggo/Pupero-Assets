#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

docker build -t pupero-api-manager -f Pupero-APIManager/Dockerfile .
docker build -t pupero-login -f Pupero-LoginBackend/Dockerfile .
docker build -t pupero-offers -f Pupero-Offers/Dockerfile .
docker build -t pupero-transactions -f Pupero-WalletManagerDB/Dockerfile .
docker build -t pupero-walletmanager -f Pupero-MoneroWalletManager/Dockerfile .
docker build -t pupero-database -f Pupero-CreateDB/Dockerfile .
docker build -t pupero-flask -f Pupero-LoginFrontEnd/Dockerfile .
docker build -t pupero-sweeper -f Pupero-Sweeper/Dockerfile .
docker build -t pupero-admin -f Pupero-AdminAPI/Dockerfile .
docker build -t pupero-monerod -f Pupero-monerod/Containerfile .

echo "All images built."
