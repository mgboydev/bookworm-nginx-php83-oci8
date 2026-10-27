#!/usr/bin/env bash
set -Eeuo pipefail

echo "========== [START] Base Image Initialization =========="

APP_DIR="/var/www/html"
ORACLE_NET_DIR="${TNS_ADMIN:-/usr/local/instantclient/network/admin}"
APP_START_SCRIPT="/usr/local/bin/start-laravel.sh"

# Prepare runtime directories
mkdir -p \
    /run/php \
    /run/supervisor \
    "${ORACLE_NET_DIR}" \
    /etc/supervisor/conf.d

# Oracle SQL*Net
if [[ ! -f "${ORACLE_NET_DIR}/sqlnet.ora" ]]; then
    printf '%s\n' 'DISABLE_OOB=ON' > "${ORACLE_NET_DIR}/sqlnet.ora"
fi

echo "Oracle SQL*Net: ${ORACLE_NET_DIR}/sqlnet.ora"

# Optional: configure Nginx worker processes
if [[ "${NGINX_AUTO_WORKERS:-false}" == "true" ]]; then
    PROCS="$(nproc)"

    if [[ "${PROCS}" -gt 0 ]]; then
        echo "Configuring Nginx worker_processes: ${PROCS}"

        sed -i -E \
            's/^[[:space:]]*worker_processes[[:space:]]+[^;]+;/worker_processes '"${PROCS}"';/' \
            /etc/nginx/nginx.conf
    fi
fi

# Validate configuration before starting services
echo "Validating Nginx configuration..."
nginx -t

# Start Supervisor exactly once
echo "Starting Supervisor..."
exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
