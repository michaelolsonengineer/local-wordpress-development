#!/bin/bash

# This is incomplete, fix this for interactive prompt later

### Create a new user with sudo privileges
### This script is intended to be run as root
### Usage: bash create_linux_user.sh

create_linux_user() {
    echo "FIXME: Don't run this unless you are sure, fix this for interactive prompt later"
    exit 1

    local NEW_USER="${1:-wordpress}"
    local NEW_PASSWORD="${2:-wordpress}"
    local NEW_UID="${3-}"
    local NEW_GID="${4-}"
    local NEW_HOME="${5-}"
    local NEW_SHELL="${6:-/bin/bash}"

    # Check if the user already exists
    if id "${NEW_USER}" &>/dev/null; then
        echo "User ${NEW_USER} already exists."
        return 1
    fi

    # Check if the group already exists
    if getent group "${NEW_USER}" &>/dev/null; then
        echo "Group ${NEW_USER} already exists."
        return 1
    fi

    groupadd --gid "${NEW_GID}" "${NEW_USER}" &&
        useradd \
            --no-log-init \
            --uid "${NEW_UID}" \
            --gid "${NEW_GID}" \
            --home-dir "${NEW_HOME}" \
            --create-home \
            --shell "${NEW_SHELL}" \
            "${NEW_USER}" &&
        echo "${NEW_USER}:${NEW_PASSWORD}" | chpasswd &&
        usermod -aG sudo "${NEW_USER}"

    # Fix sudo for users on shell
    echo "${NEW_USER} ALL=(ALL) NOPASSWD:ALL" >>/etc/sudoers &&
        echo "%sudo ALL=(ALL:ALL) NOPASSWD:ALL" >>/etc/sudoers &&
        touch "${NEW_HOME}/.sudo_as_admin_successful"
}
