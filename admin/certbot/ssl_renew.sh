#!/bin/bash

set -e

# sudo crontab -e

# Run every every 5th minute
# */5 * * * * ${HOME}/wordpress/ssl_renew.sh >> /var/log/cron.log 2>&1

# Run At 12:02AM
# 2 12 * * * ${HOME}/wordpress/ssl_renew.sh >> /var/log/cron.log 2>&1

cd "${HOME}/wordpress/" || exit 1
/usr/bin/docker compose --no-ansi run certbot renew &&
  /usr/bin/docker compose --no-ansi kill -s SIGHUP webserver
/usr/bin/docker system prune -af
