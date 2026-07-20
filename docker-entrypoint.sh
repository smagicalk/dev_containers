#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${SSH_PASSWORD:-}" ]]; then
  echo "ERROR: SSH_PASSWORD environment variable is required." >&2
  exit 1
fi

printf 'root:%s\n' "$SSH_PASSWORD" | chpasswd
unset SSH_PASSWORD

if [[ -n "${SSH_PUBLIC_KEY:-}" ]]; then
  install -d -m 700 /root/.ssh
  printf '%s\n' "$SSH_PUBLIC_KEY" > /root/.ssh/authorized_keys
  chmod 600 /root/.ssh/authorized_keys
  unset SSH_PUBLIC_KEY
fi

ssh-keygen -A

if [[ $# -gt 0 ]]; then
  exec "$@"
fi

exec /usr/sbin/sshd -D -e
