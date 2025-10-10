#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

docker build -t blackmine57/pupero-api-manager:latest -f Pupero-APIManager/Dockerfile .
docker push blackmine57/pupero-api-manager:latest

docker build -t blackmine57/pupero-login:latest -f Pupero-LoginBackend/Dockerfile .
docker push blackmine57/pupero-login:latest

docker build -t blackmine57/pupero-offers:latest -f Pupero-Offers/Dockerfile .
docker push blackmine57/pupero-offers:latest

docker build -t blackmine57/pupero-transactions:latest -f Pupero-WalletManagerDB/Dockerfile .
docker push blackmine57/pupero-transactions:latest

docker build -t blackmine57/pupero-walletmanager:latest -f Pupero-MoneroWalletManager/Dockerfile .
docker push blackmine57/pupero-walletmanager:latest

docker build -t blackmine57/pupero-database:latest -f Pupero-CreateDB/Dockerfile .
docker push blackmine57/pupero-database:latest

docker build -t blackmine57/pupero-flask:latest -f Pupero-LoginFrontEnd/Dockerfile .
docker push blackmine57/pupero-flask:latest

docker build -t blackmine57/pupero-sweeper:latest -f Pupero-Sweeper/Dockerfile .
docker push blackmine57/pupero-sweeper:latest

docker build -t blackmine57/pupero-admin:latest -f Pupero-AdminAPI/Dockerfile .
docker push blackmine57/pupero-admin:latest

docker build -t blackmine57/pupero-monerod:latest -f Pupero-monerod/Containerfile .
docker push blackmine57/pupero-monerod:latest

docker build -t blackmine57/pupero-matrix:latest -f Pupero-Assets/synapse/docker/Dockerfile Pupero-Assets/synapse/
docker push blackmine57/pupero-matrix:latest

#docker build -t blackmine57/pupero-element:latest -f Pupero-Assets/element-web/Dockerfile Pupero-Assets/element-web/
#docker push blackmine57/pupero-element:latest

docker build -t blackmine57/pupero-explorer:latest -f Pupero-Assets/onion-monero-blockchain-explorer/Dockerfile Pupero-Assets/onion-monero-blockchain-explorer/
docker push blackmine57/pupero-explorer:latest

echo "All images built."
