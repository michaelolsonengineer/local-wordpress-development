#!/bin/bash

# Exit on error
set -e

# Throw error if undefined variable used
set -u

##########################################################
# Adapted original bash template script from Kyle Smith
##########################################################

if [ -z "${TOOLS_COMMON_DIR-}" ]; then
    # shellcheck disable=SC2155
    declare -xg SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${SCRIPT_DIR}/../../tools/common/constants.sh"
    source "${SCRIPT_DIR}/../../tools/common/general_utils.sh"
fi

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

    This admin script will create new configurable linux user with following
    configurations provided from the .env provided at the root of the project
    or specified in the command line. The command prompt will information
    about the user to be created.

# How to Use:
        # in ${SCRIPT_DIR}
        ./$0 <...>

# Inputs:
    --env-file:
        the configuration file for reading default user and password

    --super-user:
        make the created user a sudo user

    ----no-sudo-password:
        disable need for password; not recommended for production server. Usee only for local development

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

    # Set default values
    declare -xg NEW_USER="wordpress"
    declare -xg NEW_PASSWORD="${NEW_USER}" # Prompt user to recommend strongly changing this (only for local dev)
    declare -xg NEW_HOME="/home/${NEW_USER}"
    declare -xg NEW_SHELL="/bin/bash"
    declare -xg ENVIRONMENT_FILE="${WORKSPACE}/.env"
    declare -xg MAKE_SUPER_USER="false"
    declare -xg DISABLE_PASSWORD_FOR_NEW_USER="false"

    # Parse options
    while (($#)); do
        case "${1}" in
        --env-file)
            shift
            ENVIRONMENT_FILE="${1}"
            ;;
        --super-user)
            MAKE_SUPER_USER="true"
            ;;
        --no-sudo-password)
            DISABLE_PASSWORD_FOR_NEW_USER="true"
            ;;
        -h | --help | help)
            __script_help
            exit
            ;;

        esac
        shift
    done

    log INFO "---------------------------------------------------------------------"
    log INFO "NEW_USER:                                  ${NEW_USER}"
    log INFO "NEW_PASSWORD:                              ${NEW_PASSWORD}"
    log INFO "NEW_HOME:                                  ${NEW_HOME}"
    log INFO "NEW_SHELL:                                 ${NEW_SHELL}"
    log INFO "ENVIRONMENT_FILE:                          ${ENVIRONMENT_FILE}"
    log INFO "MAKE_SUPER_USER:                           ${MAKE_SUPER_USER}"
    log INFO "DISABLE_PASSWORD_FOR_NEW_USER:             ${DISABLE_PASSWORD_FOR_NEW_USER}"
    log INFO "---------------------------------------------------------------------"
}

# __script_init (optional)
#       Initialize and validate the scripts environment.  This stage runs after
#       __script_parse_opts, so global variables set by parse_opts will be
#       available here.
#       This stage is useful for ensuring build tools are present, and ensuring
#       the necessary environment variables are set.
__script_init() { # Optional
    log INFO "Initializing $0 ..."

    # Check if the environment file exists
    if [ ! -e "${ENVIRONMENT_FILE-}" ]; then
        log WARN "No environment configured default file ${ENVIRONMENT_FILE} detected."
    else
        # grab all the data from the password file
        NEW_USER=$(sed -n "s/^DATABASE_USER=\"\(.*\)\"$/\1/p" "${ENVIRONMENT_FILE}")
        NEW_PASSWORD=$(sed -n "s/^DATABASE_PASSWORD=\"\(.*\)\"$/\1/p" "${ENVIRONMENT_FILE}")

        echo -en "Would you like to create the linux user: ${NEW_USER}"
        echo -en "With the password: ${NEW_PASSWORD}"

        echo -en "\n"
        read -rp "Is the information correct? [Y/n] " confirmation
        confirmation=${confirmation,,}
        if [[ "${confirmation}" =~ ^(yes|y)$ ]] || [ -z "${confirmation}" ]; then
            return
        else
            unset NEW_USER NEW_PASSWORD
        fi

        echo -en "\n"
        read -rp "Username: " NEW_USER
        echo -en "\n"
        read -s -rp "Password: " NEW_PASSWORD
        echo -en "\n"

        NEW_HOME="/home/${NEW_USER}"
    fi
}

# __script_exec
#       Execute the script! This function receives no arguments and it assumes
#       the environment is fully configured before entering __script_exec. This
#       architecture enforces good script writing practices and reduces script
#       boilerplate for error handling.
__script_exec() { # Required
    # Check if the script is being run as root
    if [ "$(id -u)" -ne 0 ]; then
        error "This script must be run as root. Please run again with sudo or as root user."
        exit 1
    fi

    # Check if the group already exists
    if getent group "${NEW_USER}" &>/dev/null; then
        error "Group ${NEW_USER} already exists."
        return 1
    else
        groupadd "${NEW_USER}" "${NEW_USER}"
    fi

    # Check if the user already exists
    if id "${NEW_USER}" &>/dev/null; then
        error "User ${NEW_USER} already exists."
        return 1
    else
        useradd \
            --no-log-init \
            --home-dir "${NEW_HOME}" \
            --create-home \
            --shell "${NEW_SHELL}" \
            "${NEW_USER}"
    fi

    # Set Password
    echo "${NEW_USER}:${NEW_PASSWORD}" | chpasswd

    if [ "${MAKE_SUPER_USER}" = "true" ]; then
        usermod -aG sudo "${NEW_USER}"
    fi

    # Fix sudo for users on shell
    if [ "${DISABLE_PASSWORD_FOR_NEW_USER}" = "true" ]; then
        echo "${NEW_USER} ALL=(ALL) NOPASSWD:ALL" >>/etc/sudoers &&
            echo "%sudo ALL=(ALL:ALL) NOPASSWD:ALL" >>/etc/sudoers &&
            touch "${NEW_HOME}/.sudo_as_admin_successful"
    fi
}

# __script_succeed (optional)
#       If __script_exec succeeds, __script_succeed is evaluated.  This can be
#       used to provide feedback to the user about the success, or trigger
#       post-script-success logic
__script_succeed() { # Optional
    log INFO "$0 succeeded!"
}

# __script_failed (optional)
#       If __script_exec fails, __script_failed is evaluated.  This can be used
#       to provide feedback to the user about the failure and trigger
#       post-script-failed logic.
__script_failed() { # Optional
    log INFO "Could not execute $0 successfully"
}

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
    # log INFO "Cleaning up potential dirty state ..."
}

trap __script_cleanup EXIT

__script_parse_opts "${@}"
__script_init
__script_exec
