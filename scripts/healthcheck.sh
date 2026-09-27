#!/usr/bin/env bash
set -e

# Docker HEALTHCHECK runs outside entrypoint.sh, so it cannot read the
# exported credentials. ttyd answers 401 (auth required) instead of 200 when
# no Authorization header is sent - that still proves the server is alive.
PORT_TO_CHECK="${PORT:-8080}"
CODE="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 4 \
  "http://127.0.0.1:${PORT_TO_CHECK}/" || echo 000)"

# 200 = terminal reachable, 401 = reachable and asking for login, 000 = down.
case "$CODE" in
  200|401) exit 0 ;;
  *)
    echo "healthcheck failed: HTTP ${CODE} on port ${PORT_TO_CHECK}" >&2
    exit 1
    ;;
esac
