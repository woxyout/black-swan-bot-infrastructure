#!/usr/bin/env bash

set -Eeuo pipefail

APP_DIR="/srv/black-swan"
BACKUP_DIR="${APP_DIR}/runtime/backups"

cd "${APP_DIR}"

docker compose exec -T bot python /app/backup_db.py

restic backup "${BACKUP_DIR}" \
  --tag sqlite

restic forget \
  --tag sqlite \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 6 \
  --prune
