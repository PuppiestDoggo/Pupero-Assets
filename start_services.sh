#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

# Load env variables if present
set +u
[ -f .env ] && . ./.env || true
set -u
: "${DB_ROOT_PASSWORD:?DB_ROOT_PASSWORD is required (set in .env or environment)}"
: "${DB_NAME:?DB_NAME is required (set in .env or environment)}"

# Build images if not exist
docker images pupero-createdb >/dev/null 2>&1 || docker build -t pupero-createdb -f DB/Dockerfile .
docker images pupero-login >/dev/null 2>&1 || docker build -t pupero-login -f Login/Dockerfile .
docker images pupero-offers >/dev/null 2>&1 || docker build -t pupero-offers -f Offers/Dockerfile .
docker images pupero-transactions >/dev/null 2>&1 || docker build -t pupero-transactions -f Transactions/Dockerfile .
docker images pupero-api-manager >/dev/null 2>&1 || docker build -t pupero-api-manager -f APIManager/Dockerfile .
docker images pupero-flask >/dev/null 2>&1 || docker build -t pupero-flask -f FlaskProject/Dockerfile .

# Start each service container individually (detached)
docker run -d --name pupero-createdb -e MYSQL_ROOT_PASSWORD="${DB_ROOT_PASSWORD}" -e MYSQL_DATABASE="${DB_NAME}" -p 3306:3306 -v pupero_db_data:/var/lib/mysql pupero-createdb || true

# Wait for DB to be ready
sleep 5


# Start service containers
docker run -d --name pupero-login --network host -e DATABASE_URL="mariadb+mariadbconnector://root:${DB_ROOT_PASSWORD}@127.0.0.1:3306/${DB_NAME}" -e LOGIN_PORT=8001 pupero-login

docker run -d --name pupero-offers --network host -e DATABASE_URL="mariadb+mariadbconnector://root:${DB_ROOT_PASSWORD}@127.0.0.1:3306/${DB_NAME}" -e OFFERS_PORT=8002 pupero-offers

docker run -d --name pupero-transactions --network host -e DATABASE_URL="mariadb+mariadbconnector://root:${DB_ROOT_PASSWORD}@127.0.0.1:3306/${DB_NAME}" -e TRANSACTIONS_PORT=8003 pupero-transactions

docker run -d --name pupero-api-manager --network host -e API_MANAGER_PORT=8000 -e LOGIN_SERVICE_URL=http://127.0.0.1:8001 -e OFFERS_SERVICE_URL=http://127.0.0.1:8002 -e TRANSACTIONS_SERVICE_URL=http://127.0.0.1:8003 pupero-api-manager

docker run -d --name pupero-flask --network host -e PORT=5000 -e BACKEND_URL=http://127.0.0.1:8000/auth -e OFFERS_SERVICE_URL=http://127.0.0.1:8000 -e TRANSACTIONS_SERVICE_URL=http://127.0.0.1:8000/transactions pupero-flask

echo "Services started with host networking. Access:"
echo "  API Manager: http://127.0.0.1:8000"
echo "  Login: http://127.0.0.1:8001"
echo "  Offers: http://127.0.0.1:8002"
echo "  Transactions: http://127.0.0.1:8003"
echo "  Frontend: http://127.0.0.1:5000"