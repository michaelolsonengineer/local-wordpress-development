#!/bin/bash

# set -e: Exit on error
# set -u: Throw error if undefined variable used
set -e -u

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

    log WARN "Stopping site..."
    docker compose down

    log WARN "Deleting ALL stopped containers..."
    docker container prune -f
    # if [[ $(docker ps -q) ]]; then
    #   # shellcheck disable=SC2046
    #   docker rm $(docker ps -a -q --filter "status=exited") --force
    # fi

    log WARN "Delete \"${SCRIPT_DIR}/src\"?"
    if confirm; then
      sudo rm -rf "${SCRIPT_DIR}/src"
    fi

    log WARN "Deleting ALL stopped volumes defined in docker-compose.yml..."
    local compose_volume
    for compose_volume in $(yq '.volumes | keys[]' docker-compose.yml); do
      local created_volume=${SCRIPT_DIR##*/}_${compose_volume//\"/}
      log WARN "removing volume: ${created_volume}"
      if docker volume inspect "${created_volume}" 1>/dev/null 2>&1; then
        docker volume rm "${created_volume}" 1>/dev/null 2>&1 ||
          log !!!WARNING!!! "Docker volume \"${created_volume}\" removed."
      fi
    done

    log INFO "Docker Containers Check: ... $(docker ps -a -q)"
    [ -z "$(docker ps -a -q)" ] ||
      error "Docker containers not removed"

    log INFO "Docker Volume Check: ... $(docker volume ls -q)"
    [ -z "$(docker volume ls -q)" ] ||
      error "Docker volumes not removed"

    log INFO "Nuke detonated successfully"
  fi
}
