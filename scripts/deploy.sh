#!/usr/bin/env bash

set -Eeuo pipefail

APP_DIR="/srv/black-swan"
ENV_FILE="${APP_DIR}/.env"
SERVICE="bot"
NEW_TAG="${1:-}"

if [[ ! "${NEW_TAG}" =~ ^sha-[0-9a-f]{40}$ ]]; then
  echo "Invalid image tag: ${NEW_TAG}" >&2
  exit 2
fi

cd "${APP_DIR}"

PREVIOUS_TAG="$(
  sed -n 's/^IMAGE_TAG=//p' "${ENV_FILE}"
)"

if [[ ! "${PREVIOUS_TAG}" =~ ^(main|sha-[0-9a-f]{40})$ ]]; then
  echo "Invalid previous IMAGE_TAG: ${PREVIOUS_TAG}" >&2
  exit 3
fi

echo "Creating pre-deploy backup"
systemctl start black-swan-backup.service

rollback() {
  exit_code=$?
  trap - ERR

  echo "Deployment failed, rolling back to ${PREVIOUS_TAG}" >&2

  sed -i \
    "s/^IMAGE_TAG=.*/IMAGE_TAG=${PREVIOUS_TAG}/" \
    "${ENV_FILE}"

  docker compose up -d --no-deps "${SERVICE}" || true

  exit "${exit_code}"
}

trap rollback ERR

sed -i \
  "s/^IMAGE_TAG=.*/IMAGE_TAG=${NEW_TAG}/" \
  "${ENV_FILE}"

docker compose pull "${SERVICE}"
docker compose up -d --no-deps "${SERVICE}"

for attempt in {1..12}; do
  container_id="$(docker compose ps -q "${SERVICE}")"

  if [[ -n "${container_id}" ]] \
    && [[ "$(
      docker inspect \
        --format '{{.State.Status}}' \
        "${container_id}"
    )" == "running" ]] \
    && docker compose logs \
      --since 90s "${SERVICE}" 2>&1 \
      | grep -q "Run polling for bot"
  then
    trap - ERR
    echo "Deployment successful: ${NEW_TAG}"
    exit 0
  fi

  sleep 5
done

echo "Bot did not become healthy" >&2
docker compose logs --tail=50 "${SERVICE}" >&2
false
