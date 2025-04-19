#!/bin/bash
# shellcheck disable=SC2155

# set -e: Exit on error
# set -u: Throw error if undefined variable used
set -e -u

declare -xg TOOLS_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

declare -xg WORKSPACE="$(cd "${TOOLS_COMMON_DIR}/../../" && pwd)"
#------------------------------------------------------------------------------

declare -xg DOCKER="/usr/bin/docker"
declare -xg WEBSERVER_ROOT="/var/www/html"
declare -xg WS_NGINX_DIR="${WORKSPACE}/nginx"
declare -xg WS_ENV_FILE="${WORKSPACE}/.env"

#=======================================
#       Color and style definitions
#=======================================

# See https://en.wikipedia.org/wiki/ANSI_escape_code
# for more colors
# and https://tldp.org/HOWTO/Bash-Prompt-HOWTO/x361.html
# for more info on tput
# and https://stackoverflow.com/questions/5947742/how-to-change-the-output-color-of-echo-in-linux
declare -xg FG_BLACK="$(tput setaf 0)"
declare -xg FG_RED="$(tput setaf 1)"
declare -xg FG_GREEN="$(tput setaf 2)"
declare -xg FG_YELLOW="$(tput setaf 3)"
declare -xg FG_BLUE="$(tput setaf 4)"
declare -xg FG_MAGENTA="$(tput setaf 5)"
declare -xg FG_CYAN="$(tput setaf 6)"
declare -xg FG_WHITE="$(tput setaf 7)"
declare -xg STYLE_RESET="$(tput sgr0)"

# source https://stackoverflow.com/a/28938235
declare -xg STYLE_RESET='\033[0;0m' # Text Reset
declare -xg BOLD='\033[1m'          # Text Emphasis
declare -xg TAB="  "                # two spaces, equivalent to a tab

# Regular Colors
declare -xg BLACK='\033[0;30m'   # Black Text
declare -xg RED='\033[0;31m'     # Red Text
declare -xg GREEN='\033[0;32m'   # Green Text
declare -xg YELLOW='\033[0;33m'  # Yellow Text
declare -xg BLUE='\033[0;34m'    # Blue Text
declare -xg MAGENTA='\033[0;35m' # Magenta Text
declare -xg PURPLE="${MAGENTA}"  # alias for Magenta
declare -xg CYAN='\033[0;36m'    # Cyan Text
declare -xg WHITE='\033[0;37m'   # White Text

# Bold
declare -xg BBLACK='\033[1;30m'  # Text Emphasize Black
declare -xg BRED='\033[1;31m'    # Text Emphasize Red
declare -xg BGREEN='\033[1;32m'  # Text Emphasize Green
declare -xg BYELLOW='\033[1;33m' # Text Emphasize Yellow
declare -xg BBLUE='\033[1;34m'   # Text Emphasize Blue
declare -xg BPURPLE='\033[1;35m' # Text Emphasize Purple
declare -xg BCYAN='\033[1;36m'   # Text Emphasize Cyan
declare -xg BWHITE='\033[1;37m'  # Text Emphasize White
