#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

read -r -p "This will remove the MariaDB volume (db_data) and reinitialize the database. Continue? [y/N] " ans
case "${ans:-N}" in
  [yY][eE][sS]|[yY]) ;;
  *) echo "Aborted."; exit 1;;
 esac

echo "Stopping stack..."
docker compose down -v

echo "Rebuilding DB image and starting fresh..."
docker compose up -d --build database

echo "Waiting 5s for DB to initialize..."
sleep 5

echo "Starting remaining services..."
docker compose up -d

echo "Done. Use 'docker compose logs -f database' to tail DB initialization logs."