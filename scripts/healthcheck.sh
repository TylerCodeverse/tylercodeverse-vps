#!/usr/bin/env bash
set -e
PORT_TO_CHECK="${PORT:-8080}"
curl -fsS --max-time 4 "http://127.0.0.1:${PORT_TO_CHECK}/" >/dev/null
