#!/bin/bash

# Exit on error
set -e

# Throw error if undefined variable used
set -u

# shellcheck disable=SC2155
declare -xg TOOLS_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2155
declare -xg WORKSPACE="$(cd "${TOOLS_COMMON_DIR}/../../" && pwd)"
#------------------------------------------------------------------------------

declare -xg DOCKER="/usr/bin/docker"
