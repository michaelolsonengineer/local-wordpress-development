#!/bin/bash

# sudo crontab -e
# 0 */5 * * * ${HOME}/wordpress/ssl_renew.sh >> /var/log/cron.log 2>&1
# 0 12 * * * ${HOME}/wordpress/ssl_renew.sh >> /var/log/cron.log 2>&1

set -e

# shellcheck disable=SC2155
declare -xg SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER="/usr/bin/docker"

cd "${HOME}/wordpress/" || exit 1

${DOCKER} compose --no-ansi run certbot renew && ${DOCKER} compose --no-ansi kill -s SIGHUP webserver
${DOCKER} system prune -af
