#!/usr/bin/env bash

set -Eeuo pipefail

REQUESTED_COMMAND="${SSH_ORIGINAL_COMMAND:-}"

if [[ "${REQUESTED_COMMAND}" =~ ^deploy[[:space:]](sha-[0-9a-f]{40})$ ]]; then
  exec sudo /srv/black-swan/scripts/deploy.sh "${BASH_REMATCH[1]}"
fi

echo "Only deployment commands are allowed" >&2
exit 64
