#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

docker compose up -d --build

echo "All services are starting. Use 'docker compose logs -f' to tail logs."