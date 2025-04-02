#!/bin/bash

set -e

# sudo crontab -e

# Run every every 5th minute
# */5 * * * * ${HOME}/workspace/admin/certbot/ssl_renew.sh >> /var/log/cron.log 2>&1

# Run At 12:02AM
# 2 12 * * * ${HOME}/workspace/admin/certbot/ssl_renew.sh >> /var/log/cron.log 2>&1

cd "${HOME}/wordpress/" || exit 1
/usr/bin/docker compose run certbot renew --dry-run &&
  /usr/bin/docker compose kill -s SIGHUP webserver
/usr/bin/docker system prune -af
