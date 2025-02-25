#!/bin/bash

# Some logging
echo
echo 'nginx is up and running. You should be able to access'
echo "it under: http://${DOMAIN_NAME} or https://${DOMAIN_NAME}"

# Start nginx like normal
nginx -g 'daemon off;'
