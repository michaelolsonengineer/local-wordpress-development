#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

##########################################################
# Adapted Template for script creation belongs Kyle Smith
##########################################################

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
  echo -e "${1}: ${2}"
}

# __script_help
#       Called by the help script, this function should print out a help
#       message instructing the user on the usage of the script and return
#       cleanly.  This function can include programmatic generation of the help
#       text, but it cannot rely on any of its fellow __script functions to
#       have been called in the current context
__script_help() { # Required
  cat <<EOM
===== script_template ====

# Description:
    <Briefly Describe Scripts Purpose>

# How to Use:
    <Sample Use Case>
        ./wp_runner.sh <...>

# Inputs:
    env:
        <ENVIRONMENT_VARIABLE>: <Purpose, optionality, description>
    arg:
        <POSITIONAL_ARG | FLAG_ARG>: <Purpose, optionality, description>

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
  declare -g ARG1="${1-}"
  declare -g ARG2="${2-}"

  # [ -n "${ARG1-}" ] ||
  #   error "ARG1 must be passed"
}

# __script_init (optional)
#       Initialize and validate the scripts environment.  This stage runs after
#       __script_parse_opts, so global variables set by parse_opts will be
#       available here.
#       This stage is useful for ensuring build tools are present, and ensuring
#       the necessary environment variables are set.
__script_init() { # Optional
  echoing INFO "Initializing wp_runner.sh ..."
}

# __script_exec
#       Execute the script! This function receives no arguments and it assumes
#       the environment is fully configured before entering __script_exec. This
#       architecture enforces good script writing practices and reduces script
#       boilerplate for error handling.
__script_exec() { # Required
  echo "Hello World!!!!"
}

# __script_succeed (optional)
#       If __script_exec succeeds, __script_succeed is evaluated.  This can be
#       used to provide feedback to the user about the success, or trigger
#       post-script-success logic
__script_succeed() { # Optional
  echoing INFO "wp_runner.sh succeeded!"
}

# __script_failed (optional)
#       If __script_exec fails, __script_failed is evaluated.  This can be used
#       to provide feedback to the user about the failure and trigger
#       post-script-failed logic.
__script_failed() { # Optional
  error "Could not execute wp_runner.sh successfully"
}

# __script_cleanup (optional)
#       If defined, __script_cleanup is run as the very last step of
#       execute script, after __script_succeed/__script_failed.  This can be
#       leveraged to perform any necessary cleanup regardless of the scripts
#       exit status
__script_cleanup() { # Optional
  if [ $? -eq 0 ]; then
    __script_succeed
  else
    __script_failed
  fi

  # echoing INFO "Cleaning up potential dirty state ..."
}

trap __script_cleanup EXIT

__script_parse_opts "${@}"
__script_init
__script_exec
