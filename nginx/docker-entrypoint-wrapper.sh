#!/bin/sh
# Selects the correct nginx config template based on ENABLE_SSL / ENABLE_WWW
# then hands off to the official nginx docker entrypoint.
#
# Environment variables (set in .env / docker-compose.yml):
#   ENABLE_SSL  - "true" to use an SSL config, anything else = plain HTTP  (default: false)
#   ENABLE_WWW  - "true" to include www.$NGINX_HOST in server_name          (default: false)
#
set -e

TEMPLATES_AVAILABLE=/etc/nginx/templates-available
TEMPLATES_ACTIVE=/etc/nginx/templates

mkdir -p "${TEMPLATES_ACTIVE}"

if [ "${ENABLE_SSL:-false}" = "true" ]; then
    if [ "${ENABLE_WWW:-false}" = "true" ]; then
        SELECTED="${TEMPLATES_AVAILABLE}/default.nginx.conf.with.ssl.template"
        echo "[nginx-wrapper] SSL=on  WWW=on  → using $(basename "${SELECTED}")"
    else
        SELECTED="${TEMPLATES_AVAILABLE}/default.nginx.conf.with.ssl.no.www.template"
        echo "[nginx-wrapper] SSL=on  WWW=off → using $(basename "${SELECTED}")"
    fi
else
    SELECTED="${TEMPLATES_AVAILABLE}/default.nginx.conf.no.ssl.template"
    echo "[nginx-wrapper] SSL=off → using $(basename "${SELECTED}")"
fi

cp "${SELECTED}" "${TEMPLATES_ACTIVE}/default.conf.template"

exec /docker-entrypoint.sh "$@"
