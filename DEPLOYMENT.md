# TylerCodeverse VPS — Deployment

## 1. Upload to GitHub

Use the repository:

```text
https://github.com/TylerCodeverse/tylercodeverse-vps.git
```

From this folder:

```bash
git add .
git commit -m "feat: TylerCodeverse VPS"
git push -u origin main
```

Railway redeploys automatically on every push.

## 2. Deploy on Railway

1. Railway → **New Project** → **Deploy from GitHub repo**
2. Select `TylerCodeverse/tylercodeverse-vps`
3. Railway detects the included `Dockerfile` — no build pack change needed

## 3. Environment variables

**None are required.**

| Variable | Source | Value |
|---|---|---|
| `PORT` | set by Railway automatically | never hardcode over it |
| `WEB_USERNAME` | built into the image | `TylerDurdenDev` |
| `SSH_PASSWORD` | built into the image | `TylerDurdenDev@2011` |

## 4. Fix the "Application failed to respond" (502) error — exact clicks

Railway proxies the public domain to **one** container port. That port must be
the same one ttyd binds to. This repo reads Railway's `$PORT`, so the only
thing left to check is the UI:

1. Open the service → **Settings**
2. **Networking / Public Networking** → **Generate Domain**
3. In the domain/port selector choose the port Railway assigned
   (shown next to the service, usually `8080`) — this is `$PORT`
4. Save, wait for the deploy to finish, open the generated `https://…up.railway.app` URL
5. You should get a **browser login prompt** → `TylerDurdenDev` / `TylerDurdenDev@2011`

Why the 502 happened:

| Cause | What Railway shows |
|---|---|
| App listens on 8080, proxy targets another port | logs say listening, URL says 502 |
| App binds `127.0.0.1` instead of `0.0.0.0` | logs say listening, URL says 502 |
| Healthcheck endpoint answers 401 (basic auth) | deploy marked failed, URL 502 |
| Container crash-loop | logs restart every few seconds |

This repo fixes all four: `export PORT="${PORT:-8080}"` in the entrypoint,
`--interface 0.0.0.0` on ttyd, `healthcheckPath` removed from `railway.toml`,
and `restartPolicyType = "ON_FAILURE"`.

## 5. SSH (TCP Proxy, port 2222)

1. Service → **Settings** → **Networking**
2. Add a **TCP Proxy** and map it to container port **2222**
3. Railway prints a public host + port

```text
Host:   <Railway TCP Proxy host>
Port:   <Railway TCP Proxy port>
User:   TylerDurdenDev
Pass:   TylerDurdenDev@2011
```

```bash
ssh -p <PORT> TylerDurdenDev@<TCP_PROXY_HOST>
```

If TCP Proxy is unavailable on your plan, the browser terminal still works —
use `sudo` inside it instead of SSH.

## 6. Persistence

Create/attach a Railway Volume and mount it at:

```text
/data
```

## 7. Testing checklist

```bash
# inside the browser terminal
whoami                      # TylerDurdenDev
pwd                         # /data
echo ok > /data/test.txt && cat /data/test.txt

# from your machine
curl -sI https://<your-domain>.up.railway.app/
# expect HTTP/1.1 401  -> server is up and auth is enforced

curl -sI -u TylerDurdenDev:TylerDurdenDev@2011 https://<your-domain>.up.railway.app/
# expect HTTP/1.1 200

# websocket test (should return 101 or 401, never 502)
curl -sI -u TylerDurdenDev:TylerDurdenDev@2011 \
  -H 'Connection: Upgrade' -H 'Upgrade: websocket' \
  -H 'Sec-WebSocket-Version: 13' -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' \
  https://<your-domain>.up.railway.app/ws
```

Port checks inside the container:

```bash
ss -tlnp | grep -E '8080|2222'   # both must be LISTEN on 0.0.0.0
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8080/   # 401
```

## 8. Troubleshooting matrix

| Symptom | Cause | Fix |
|---|---|---|
| 502 "Application failed to respond" | proxy port ≠ listening port | set domain port = `$PORT` (§4) |
| 502 but logs show "Listening" | bound to `127.0.0.1` | keep `--interface 0.0.0.0` |
| Deploy failed on healthcheck | healthcheck got 401 | no `healthcheckPath` in railway.toml (already removed) |
| Black screen, no cursor input | ttyd read-only | keep `--writable` (`-W`) |
| Page loads, WebSocket fails | origin blocked / auth header missing | keep `--check-origin`, log in once on the same URL |
| WebSocket 400 on Railway | proxy sent no `Upgrade` headers | use the Railway-generated HTTPS domain, not a custom one without TLS |
| 401 with correct password | wrong `Authorization` parsing | password must not contain `:` — current one doesn't |
| ttyd exits immediately | `su` cannot find the user | entrypoint creates `TylerDurdenDev` before supervisord starts |
| SSH connection refused | TCP Proxy missing | add TCP Proxy → container port 2222 (§5) |
| SSH "Permission denied" | wrong username/password | use `TylerDurdenDev` / `TylerDurdenDev@2011` |
| `sudo: a terminal is required` | no TTY | use the browser terminal or `ssh -t` |
| Files disappear after redeploy | no volume | attach a Volume at `/data` |
| `apt` permission denied | running as non-root | use `sudo apt-get` (passwordless for apt) |
| Container restarts every few seconds | process crashed | `railway logs` → check supervisord output |
| Slow first page load | image pulling + `ssh-keygen -A` | wait ~30s, healthcheck `start-period=20s` |

## 9. Quick Start (all commands in order)

```bash
# 1. push the fix
git add . && git commit -m "fix: \$PORT + ttyd auth + healthcheck" && git push

# 2. Railway UI
#    Settings -> Networking -> Public Networking -> Generate Domain
#    pick the $PORT the service shows (8080) -> Save

# 3. open the URL, login
#    TylerDurdenDev / TylerDurdenDev@2011

# 4. optional SSH
#    Settings -> Networking -> TCP Proxy -> container port 2222
#    ssh -p <proxy-port> TylerDurdenDev@<proxy-host>
```

## 10. Alternative if ttyd stays broken

`code-server` (VS Code in the browser) speaks plain HTTP and is more forgiving
of proxies. Swap the ttyd line in `Dockerfile` + `supervisord.conf`:

```dockerfile
ARG CS_VERSION=4.99.0
RUN curl -fsSL "https://github.com/coder/code-server/releases/download/v${CS_VERSION}/code-server-${CS_VERSION}-linux-amd64.tar.gz" \
    | tar -xz -C /opt && mv /opt/code-server-${CS_VERSION}-linux-amd64 /opt/code-server
```

```ini
[program:code-server]
command=/bin/bash -c 'exec /opt/code-server/bin/code-server --bind-addr 0.0.0.0:${WEB_PORT} --auth password --password ${SSH_PASSWORD} /data'
```

Alternatives with the same shape: **Wetty** (SSH over HTTP) and **GoTTY**.
