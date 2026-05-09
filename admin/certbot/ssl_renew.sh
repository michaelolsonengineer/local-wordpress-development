#!/bin/bash

# set -e: Exit on error
# set -u: Throw error if undefined variable used
set -e -u

# crontab -e
#
# Add the following line to your crontab to run this script
#
# for debugging, you can run the script manually
# Run every every 5th minute
# */5 * * * * ${HOME}/wordpress/admin/certbot/ssl_renew.sh >> ${HOME}/wordpress/log/my_cron.log 2>&1
#
# or
# for debugging, when you are more sure, you can run the script even days (roughly every other day) at 12:02 AM
# Run At 12:02AM
# 2 12 */2 * * ${HOME}/wordpress/admin/certbot/ssl_renew.sh >> ${HOME}/wordpress/log/my_cron.log 2>&1
#
# See log at with -> grep CRON /var/log/syslog

echo "Running SSL renewal script at $(date)"
cd "${HOME}/wordpress/" || exit 1

. "${HOME}/wordpress/.env"
dry_run_flag="--dry-run"

[ "${CERTBOT_STAGING_FLAG}" = "--force-renewal" ] && dry_run_flag=""
# TODO: need to logon to the certbot container to check the certificate modification date
# # Check if the certificate is was last modified within last 30 days, then renewal
# if [ -f "${HOME}/wordpress/certbot/conf/live/${DOMAIN_NAME}/fullchain.pem" ]; then
#   if [ "$(find "${HOME}/wordpress/certbot/conf/live/${DOMAIN_NAME}/fullchain.pem" -mtime +30)" ]; then
#     echo "Certificate is older than 30 days, renewing..."
#     dry_run_flag=""
#   else
#     echo "Certificate is not older than 30 days, skipping renewal."
#   fi
# else
#   echo "Certificate not found, renewing..."
#   dry_run_flag=""
# fi

/usr/bin/docker compose run certbot renew "${dry_run_flag}" &&
  /usr/bin/docker compose exec -it certbot sh -c cat /var/log/letsencrypt/letsencrypt.log &&
  /usr/bin/docker compose kill -s SIGHUP webserver
/usr/bin/docker system prune -af
