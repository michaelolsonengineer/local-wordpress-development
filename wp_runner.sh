#!/bin/bash
##########################################################
# Adapted original bash template script from Kyle Smith
##########################################################

# shellcheck disable=SC2155
declare -xg SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# __script_help
#       Called by the help script, this function should print out a help
#       message instructing the user on the usage of the script and return
#       cleanly.  This function can include programmatic generation of the help
#       text, but it cannot rely on any of its fellow __script functions to
#       have been called in the current context
__script_help() { # Required
  cat <<EOM
===== $0 ====

# Description:
    <Briefly Describe Scripts Purpose>

# How to Use:
    <Sample Use Case>
        # in ${SCRIPT_DIR}
        $0 <...>

# Inputs:
    env:
        <ENVIRONMENT_VARIABLE>: <Purpose, optionality, description>
    command:
        first-time-bring-up):
            Docker bring with certbot requires proper interaction between the machines since their the SSL certs in this setup, get
            downloaded and then are installed. This makes for a smaller form  factor and less overhead. This flag is used to
            indicate that this is the first time the server is being brought up and the script should run the necessary steps to
            bring up the server properly. This will create a file to indicate the first time bring up is complete and avoid running
            the steps in this function again in the future.

        enable-ssl-after-first-time-bring-up):
            This flag is used to indicate that the server has already been brought up and the script should run the necessary steps
            to enable SSL on the server. This will create a file to indicate the SSL is enabled complete and avoid running
            the steps in this function again in the future.

        nuke):
            nuke.
    args:

# Side Effects
    <How does the script affect the environment?>
EOM

  exit 1
}

# __script_parse_opts "${_script_opts}" (optional)
#       Parse the options passed to execute_script.  This function can store
#       values passed in via flags as global variables to be consumed by later
#       stages. (see `declare -g` for setting global variables in a function)
#       Note: arguments are not subsequently passed to __script_exec
__script_parse_opts() { # Optional
  echo "Parsing options for $0 ..."

  declare -xg _do_first_time_bring_up_flag="false"
  declare -xg _enable_ssl_after_first_time_bring_up_flag="false"

  # Parse options
  while (($#)); do
    case "${1}" in
    first-time-bring-up)
      _do_first_time_bring_up_flag="true"
      ;;
    enable-ssl-after-first-time-bring-up)
      _do_first_time_bring_up_flag="true"
      _enable_ssl_after_first_time_bring_up_flag="true"
      ;;
    nuke)
      __nuke
      exit 1
      ;;
    -h | --help | help)
      __script_help
      exit
      ;;
    *)
      echo "Unknown argument: $1"
      echo "call script with -h or --help to list available arguments"
      exit 1
      ;;
    esac
    shift
  done

  echoing INFO "---------------------------------------------------------------------"
  echoing INFO "first_time_bring_up_flag:      ${_do_first_time_bring_up_flag}"
  echoing INFO "---------------------------------------------------------------------"
}

# __script_init (optional)
#       Initialize and validate the scripts environment.  This stage runs after
#       __script_parse_opts, so global variables set by parse_opts will be
#       available here.
#       This stage is useful for ensuring build tools are present, and ensuring
#       the necessary environment variables are set.
__script_init() { # Optional
  echoing INFO "Initializing $0 ..."
}

# __script_exec
#       Execute the script! This function receives no arguments and it assumes
#       the environment is fully configured before entering __script_exec. This
#       architecture enforces good script writing practices and reduces script
#       boilerplate for error handling.
__script_exec() { # Required
  if [ "${_do_first_time_bring_up_flag}" = "true" ]; then
    echoing INFO "Running first_time_bring_up ..."
    first_time_bring_up

  fi

  #docker compose up --build
  #docker compose up -d
  #--force-recreate --no-deps webserver

  #exit 1
}

# __script_succeed (optional)
#       If __script_exec succeeds, __script_succeed is evaluated.  This can be
#       used to provide feedback to the user about the success, or trigger
#       post-script-success logic
__script_succeed() { # Optional
  echoing INFO "$0 succeeded!!!"
}

# __script_failed (optional)
#       If __script_exec fails, __script_failed is evaluated.  This can be used
#       to provide feedback to the user about the failure and trigger
#       post-script-failed logic.
__script_failed() { # Optional
  echoing INFO "$0 failed (aka the nonstandard-exit method)!!!"

  # docker container list
  # docker volume list
  # docker compose down
  # docker volume rm \
  #   "${SCRIPT_DIR%/*}_wordpress_volume" \
  #   "${SCRIPT_DIR%/*}_dbdata_volume" \
  #   "${SCRIPT_DIR%/*}_certbot-etc_volume"
  # sudo rm -rf src/

}

# function to ask for confirmation
# shellcheck disable=SC2120
confirm() {
  # call with a prompt string or use a default
  read -r -p "${1:- Are you sure you want to do this? [y/N]} " response
  case "$response" in
  [yY][eE][sS] | [yY])
    true
    ;;
  *)
    false
    ;;
  esac
}

# ===== error =====
# Description: Helper function to cleanly exit a shell when a catastrophic
#   error has occurred
# How to Use: Call when an unrecoverable catastrophe has occurred in the
#   Current shell:
#       error "${message}" "callback expression"
#   Can also be called with no message, or no callback:
#       error "" "callback expression"
#       error "${message}"
# Inputs:
#   _message (optional): Error message to log, optional w/ callback as ""
#   _callback (optional): Callback expression to be evaluated with eval after
#       printing the message and before exiting with an error
# Side Effects:
#   Optionally prints the error message and then optionally evaluates the
#   callback. Finally exits with an error code of 1
error() {
  local _message="${1-}"
  local _callback="${2-}"

  [ -n "${_message}" ] &&
    echoing ERROR "${_message}"

  [ -n "${_callback}" ] &&
    eval "${_callback}"

  exit 1
}

echoing() {
  echo -e "${1-}: ${2-}"
}

# countdown
#       countdown is a function that will print a countdown timer to the screen
#       in the format HH:MM:SS.  It takes a single argument in the format
#       Originally sourced from: https://community.unix.com/t/display-runnning-countdown-in-a-bash-script/229648/2
countdown() (
  IFS=:
  set -- $*
  secs=$((${1#0} * 3600 + ${2#0} * 60 + ${3#0}))
  while [ $secs -gt 0 ]; do
    sleep 1 &
    printf "\r%02d:%02d:%02d" $((secs / 3600)) $(((secs / 60) % 60)) $((secs % 60))
    secs=$(($secs - 1))
    wait
  done
  echo
)

# __script_cleanup
#       __script_cleanup is run as the very last step of
#       execute script, after __script_succeed/__script_failed.  This can be
#       leveraged to perform any necessary cleanup regardless of the scripts
#       exit status
__script_cleanup() {
  if [ $? -eq 0 ]; then
    __script_succeed
  else
    __script_failed
  fi

  # Optional
  # echoing INFO "Cleaning up potential dirty state ..."
}

first_time_bring_up() {
  echoing INFO "First time bring up"

  # Check if certbot license file was created
  if [ -e "${SCRIPT_DIR}/.first_time_bring_up_complete" ]; then
    echoing !!!WARNING!!! "Detected server first time bring up process completed, don't need to run this process again"
    return
  fi

  local NGINX_DIR="${SCRIPT_DIR}/nginx"

  # pull in the variables from the .env file
  . "${SCRIPT_DIR}/.env"

  # set the default nginx template to the no ssl template for first time bring up for certbot pull just certs
  rm -f "${NGINX_DIR}/templates/default.conf.template"
  cp -f "${NGINX_DIR}/templates/default.nginx.conf.no.ssl.template" "${NGINX_DIR}/templates/default.conf.template"

  docker compose up -d

  echoing INFO "Waiting for server to start up. It will take about ~2-3 minutes..."
  countdown "00:02:30"

  docker ps

  echoing INFO "Getting logs from all containers created in docker-compose.yml..."
  local compose_service
  for compose_service in $(yq '.services | keys[]' docker-compose.yml); do
    compose_service=${compose_service//\"/}
    local named_service=${CONTAINER_NAME}-${compose_service}
    echoing INFO "${named_service}: \"docker compose logs ${compose_service}\""
    docker compose logs "${compose_service}"
  done

  # Check if wordpress files were created
  [ -e "${SCRIPT_DIR}/src" ] ||
    error "Wordpress files not found. Did server appeared to fail to complete successfully"

  # Create a file to indicate first time bring up is complete and avoid
  # running this function again
  touch "${SCRIPT_DIR}"/.first_time_bring_up_complete
  echoing INFO "First time bring up complete"
}

enable_ssl_after_first_time_bring_up_flag() {
  echoing INFO "Add and Enable SSL in Webserver in configuration"

  # Check if certbot license file was created
  if [ -e "${SCRIPT_DIR}/.enable_ssl_after_first_time_bring_up_complete" ]; then
    echoing !!!WARNING!!! "Detected SSL webserver configuration process completed, don't need to run this process again"
    return
  fi

  local NGINX_DIR="${SCRIPT_DIR}/nginx"

  # pull in the variables from the .env file
  . "${SCRIPT_DIR}/.env"

  # # Set the flag to force renewal of the certbot certs
  # # FIXME: NOTE: Highly recommended to do a dry run first then switch to the --force-renewal flag
  # echoing INFO "Changing the Certbot staging flag here if we are ready for SSL certs docker-compose.yml..."
  # sed -i 's/CERTBOT_STAGING_FLAG=.*/CERTBOT_STAGING_FLAG=--staging/' "${SCRIPT_DIR}/.env"
  # # sed -i 's/CERTBOT_STAGING_FLAG=.*/CERTBOT_STAGING_FLAG=--force-renewal/' "${SCRIPT_DIR}/.env"

  # # set the default nginx template to use ssl template for first time bring up for certbot pull certs
  # echoing INFO "Changing the server configuration to use SSL certs..."
  # rm -f "${NGINX_DIR}/templates/default.conf.template"
  # cp -f "${NGINX_DIR}/templates/default.nginx.conf.with.ssl.template" "${NGINX_DIR}/templates/default.conf.template"

  # local compose_volume
  # for compose_volume in $(yq '.volumes | keys[]' docker-compose.yml); do
  #   local created_volume=${SCRIPT_DIR##*/}_${compose_volume//\"/}
  #   echoing INFO "inspecting volume: ${created_volume}"
  #   docker volume inspect "${created_volume}" 1>/dev/null 2>&1 ||
  #     echoing !!!WARNING!!! "Docker volume \"${created_volume}\" not found. Suggest possibly running \"docker volume rm ${created_volume}\" to clean up if first time startup fails if necessary"
  # done

  # # docker-compose exec webserver ls -la /etc/letsencrypt/live

  # # docker-compose up --force-recreate --no-deps certbot

  # # Check if certbot license file was created
  # [ -e "${SCRIPT_DIR}/certbot/conf/live" ] ||
  #   error "Certbot files not found. Did server appeared to fail to complete successfully"

  # Create a file to indicate first time bring up is complete and avoid
  # running this function again
  touch "${SCRIPT_DIR}"/.enable_ssl_after_first_time_bring_up_complete
  echoing INFO "SSL enabled in webserver complete"
}

# __nuke
#       This function will bring down the site and then clean up all docker containers and volumes.
#       It invoked with --nuke flag is passed to this script and will prompt the user for confirmation before proceeding
#       This function will remove all stopped containers and volumes defined in the docker-compose.yml file and it
#       will not remove any running containers. Nor will it remove any volumes not defined in the docker-compose.yml file
__nuke() {
  echo "┌────────────────────────────────────────────────────────────────────────────────┐"
  echo -e "│       \e[1;5m***************************************************************\e[0m          │"
  echo -e "│        DANGER   |   ACHTUNG   |   PELIGRO   |   ОПАСНОСТЬ   |   危险           │"
  echo -e "│       \e[1;5m***************************************************************\e[0m          │"
  echo "│                                                                                │"
  echo "│ You're about to nuke ALL containers & volumes for your site containing the.    │"
  echo "│ database and files for website ensure you backed up elsewhere as this          |"
  echo "| PERMANENT.                                                                     │"
  echo "│                                                                                │"
  echo "│ This can't be undone, data will be lost and you will be starting from fresh:   │"
  echo "│  ═> '$0 --first-time-bring-up' to bring up the site again          │"
  echo "└────────────────────────────────────────────────────────────────────────────────┘"
  if confirm; then # triggers shellcheck SC2120 for `confirm`
    echo -e "\n   \"I say we take off and nuke the entire site from orbit. It's the only way to be sure...\"\n"

    echoing WARN "Stopping site..."
    docker compose down

    echoing WARN "Deleting ALL stopped containers..."
    docker container prune -f
    # if [[ $(docker ps -q) ]]; then
    #   # shellcheck disable=SC2046
    #   docker rm $(docker ps -a -q --filter "status=exited") --force
    # fi

    echoing WARN "Delete \"${SCRIPT_DIR}/src\"?"
    if confirm; then
      sudo rm -rf "${SCRIPT_DIR}/src"
    fi

    echoing WARN "Deleting ALL stopped volumes defined in docker-compose.yml..."
    local compose_volume
    for compose_volume in $(yq '.volumes | keys[]' docker-compose.yml); do
      local created_volume=${SCRIPT_DIR##*/}_${compose_volume//\"/}
      echoing WARN "removing volume: ${created_volume}"
      if docker volume inspect "${created_volume}" 1>/dev/null 2>&1; then
        docker volume rm "${created_volume}" 1>/dev/null 2>&1 ||
          echoing !!!WARNING!!! "Docker volume \"${created_volume}\" removed."
      fi
    done

    echoing INFO "Docker Containers Check: ... $(docker ps -a -q)"
    [ -z "$(docker ps -a -q)" ] ||
      error "Docker containers not removed"

    echoing INFO "Docker Volume Check: ... $(docker volume ls -q)"
    [ -z "$(docker volume ls -q)" ] ||
      error "Docker volumes not removed"

    echoing INFO "Nuke detonated successfully"
  fi
}

# ===== Main Script Workflow =====
trap __script_cleanup EXIT

__script_parse_opts "${@}"
__script_init
__script_exec
