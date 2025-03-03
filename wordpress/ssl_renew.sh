#!/bin/bash

set -e

COMPOSE="/usr/local/bin/docker-compose --no-ansi"
DOCKER="/usr/bin/docker"

cd "${HOME}/wordpress/" || exit 1

${COMPOSE} run certbot renew && ${COMPOSE} kill -s SIGHUP webserver
${DOCKER} system prune -af
