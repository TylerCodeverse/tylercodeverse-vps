#!/usr/bin/env bash
set -Eeuo pipefail

# ================================================================
# TylerCodeverse VPS - zero-variable configuration
# The public browser terminal needs no Railway variables.
# SSH credentials are built in for convenience; change them before
# using this on a public/real-world deployment.
# ================================================================

WEB_USERNAME="TylerDurdenDev"
SSH_PASSWORD="TylerDurdenDev@2011"

# Railway injects $PORT at runtime. Pin it here so entrypoint, supervisord
# and the healthcheck all agree on ONE port (hardcoding 8080 = 502 errors).
export PORT="${PORT:-8080}"
WEB_PORT="$PORT"
export WEB_USERNAME SSH_PASSWORD WEB_PORT

log() { printf '[TylerCodeverse VPS] %s\n' "$*" >&2; }

if [[ ! "$WEB_USERNAME" =~ ^[A-Za-z][A-Za-z0-9_-]{0,31}$ ]]; then
  log "Invalid built-in Linux username."
  exit 1
fi

# Create/update the same non-root account used by both web terminal and SSH.
if ! id "$WEB_USERNAME" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "$WEB_USERNAME"
fi

usermod --shell /bin/bash "$WEB_USERNAME"
usermod -aG sudo "$WEB_USERNAME"
echo "${WEB_USERNAME}:${SSH_PASSWORD}" | chpasswd

# Give the user passwordless access only to common package/service commands.
cat > "/etc/sudoers.d/${WEB_USERNAME}" <<SUDO
${WEB_USERNAME} ALL=(root) NOPASSWD:/usr/bin/apt-get,/usr/bin/apt-cache,/usr/bin/dpkg,/usr/bin/systemctl,/usr/bin/service
SUDO
chmod 0440 "/etc/sudoers.d/${WEB_USERNAME}"

# Keep persistent user data on the Railway Volume.
mkdir -p /data/home /data/workspaces
chown -R "$WEB_USERNAME:$WEB_USERNAME" /data

if [[ ! -e "/home/$WEB_USERNAME/data" ]]; then
  ln -s /data "/home/$WEB_USERNAME/data"
fi

# Make the SSH config match the built-in username.
sed -i "s/^AllowUsers .*/AllowUsers ${WEB_USERNAME}/" /etc/ssh/sshd_config

mkdir -p /run/sshd
chmod 0755 /run/sshd
ssh-keygen -A

# Friendly terminal startup.
cat > "/home/$WEB_USERNAME/.bashrc.d-railway" <<'BASHRC'
# TylerCodeverse VPS shell profile
export PS1='\u@\h:\w\$ '
export PATH="$HOME/.local/bin:$PATH"
cd /data 2>/dev/null || true
BASHRC

touch "/home/$WEB_USERNAME/.bashrc"
grep -qxF 'source ~/.bashrc.d-railway' "/home/$WEB_USERNAME/.bashrc" 2>/dev/null || \
  echo 'source ~/.bashrc.d-railway' >> "/home/$WEB_USERNAME/.bashrc"

chown "$WEB_USERNAME:$WEB_USERNAME" \
  "/home/$WEB_USERNAME/.bashrc" \
  "/home/$WEB_USERNAME/.bashrc.d-railway"

log "Starting TylerCodeverse VPS"
log "Browser terminal: http://0.0.0.0:${WEB_PORT} (Railway \$PORT=${PORT})"
log "SSH: TCP port 2222"
log "SSH username: ${WEB_USERNAME}"
log "Browser authentication: basic auth (${WEB_USERNAME})"

exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
