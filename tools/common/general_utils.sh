#!/bin/bash

# Exit on error
set -e

# Throw error if undefined variable used
set -u

source "${TOOLS_COMMON_DIR:-.}/constants.sh"
#------------------------------------------------------------------------------

echoing() {
  echo -e "${1-}: ${2-}"
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

# ===== is_installed =====
# Description:
#     The standard conditional check if package is installed on the linux system by checking its name
# Arguments:
#     $1 - Name of the array variable (passed by name).
# Usage:
#     is_installed <package>
# Output:
#     0 if it is installed, 1 otherwise
is_installed() {
  local package=$1

  if apt -qq list "${package}" 2>/dev/null | grep -q installed; then
    return 0
  fi

  if [ -z "$(command -v "${package}")" ]; then
    return 1
  else
    return 0
  fi
}

# ===== array_2_str =====
# Description:
#     Convert an array to a single quoted string argument.
# Arguments:
#     $1 - Name of the array variable (passed by reference).
# Usage:
#     my_array=("element1" "element2" "element3")
#     result=$(array_2_str my_array)
#     echo $result
# Output:
#     Echoes the array elements as a string, each element quoted and space-separated.
array_2_str() {
  local -n array=$1
  local str=""

  for item in "${array[@]}"; do
    str+=" \"${item}\""
  done
  echo "${str}"
}

# ===== set_if_empty =====
# Description:
#     Globally sets a variable to a default value if it is not already set.
# Arguments:
#     $1 - Name of the variable to check and set.
#     $2 - Default value to set if the variable is unset or empty.
# Usage:
#     set_if_empty VAR_NAME "default_value"
# Output:
#     If VAR_NAME is unset or empty, sets it globally to "default_value".
set_if_empty() {
  local var_name=$1
  local default_value=$2

  if [[ -z "${!var_name-}" ]]; then
    echoing WARN "$var_name is not specified! Using default value."
    declare -gx "$var_name=$default_value"
    echoing WARN "Using $var_name=${!var_name}"
  fi
}

#------------------------------------------------------------------------------
# Verify docker permissions
# Usage: verify_docker_permission <quiet>
# quiet: when set to "-q", silences messages for scripts that just need status and no feedback
# Return: 0 if success, 1 if error
verify_docker_permission() {
  local quiet=${1:-v}
  if [[ ${quiet} != "-q" ]]; then
    echoing INFO "Verifying docker permission ..."
  fi

  # Check for error conditions
  if ! docker ps &>/dev/null; then
    if ! groups | grep -q docker; then
      echoing WARN "User has not been added to the docker group."
      echoing INFO "If the command 'groups | grep docker' does not print anything and your docker installation does not include
      your user for the proper permissions, please run the following command:"
      echoing INFO "\"sudo usermod -aG docker ${USER}\""
      echoing INFO "A reboot will then be required of the system."
    else
      echoing WARN "The docker test command 'docker ps' has failed. \
This is likely due to an improper docker installation or a docker permission issue."
    fi
    return 1
  fi

  return 0
}

# ===== error_if_empty =====
# Description:
#     Exits the script with an error if the specified variable is empty.
# Arguments:
#     $1 - Name of the variable to check.
#     $2 - Error message to display if the variable is empty.
# Usage:
#     error_if_empty VAR_NAME "Error message"
# Output:
#     If VAR_NAME is empty, exits the script and prints "Error message".
error_if_empty() {
  local var_name=$1
  local msg=$2

  if [[ -z "${!var_name-}" ]]; then
    error "$msg can't be empty"
  fi
}

# ===== error_if_dir_not_exist =====
# Description:
#     Exits the script with an error if the specified directory does not exist.
# Arguments:
#     $1 - Path to the directory to check.
# Usage:
#     error_if_dir_not_exist "/path/to/directory"
#     error_if_dir_not_exist "${my_dir}"
# Output:
#     If the directory does not exist, exits the script and prints an error message.
error_if_dir_not_exist() {
  local dir=$1

  [ -d "${dir-}" ] || error "${dir-} does not exist!"
}

# ===== validate_selected_items =====
# Description:
#     Validates if each item in the first array is present in the second array.
# Arguments:
#     $1 - Name of the array variable containing selected items (passed by reference).
#     $2 - Name of the array variable containing supported items (passed by reference).
# Usage:
#     selected_items=("item1" "item3")
#     supported_items=("item1" "item2" "item3")
#     validate_selected_items selected_items supported_items
# Output:
#     If an item in selected_items is not found in supported_items, exits script with an error.
validate_selected_items() {
  local -n selected=$1
  local -n supported=$2

  for item in "${selected[@]}"; do
    local found=false
    for support in "${supported[@]}"; do
      if [[ "$item" == "$support" ]]; then
        found=true
        break
      fi
    done
    if [[ "$found" == false ]]; then
      error "-: error: invalid choice: '${item}' (choose from '${supported[*]}')"
    fi
  done
}

# ===== is_item_in_list =====
# Description:
#     Check if string ($1) is in variable ($2)
# Arguments:
#     $1 - search string
#     $2 - List of strings to search
# Usage:
#     is_item_in_list $aList $anItem
# Output:
#     return 0 aka true if search string in list
#     else 1 aka false
is_item_in_list() {
  local anItem=$1
  local aList="${*:2}"

  anItem=$(trim "$anItem")
  for item in "${aList[@]}"; do
    [[ $item =~ $anItem ]] && return 0
  done
  return 1
}

# ===== is_item_in_array =====
# Description:
#     Check if a specific item is present in an array of items.
# Arguments:
#     $1 - The item to check for.
#     $2 - The array of items  to search within (e.g., "${array[@]}").
# Usage:
#     array=("item1" "item2" ...)
#     is_item_in_array "item_to_check" "${array[@]}"
# Output:
#     Returns 0 (true) if the item is found in the array.
#     Returns 1 (false) if the item is not found in the array.
is_item_in_array() {
  local item_to_check="$1"
  shift
  local items=("$@")
  local item
  for item in "${items[@]}"; do
    if [[ "$item" == "$item_to_check" ]]; then
      return 0
    fi
  done

  return 1
}

# ===== file_contains_string =====
# Description:
#     Check if a specific string is present in a given file.
# Arguments:
#     $1 - The file to search in.
#     $2 - The string to search for.
# Usage:
#     file_contains_string "path/to/file" "string_to_search"
# Output:
#     Returns 0 (true) if the string is found in the file.
#     Returns 1 (false) if the string is not found in the file.
file_contains_string() {
  local file=$1
  local string=$2

  # Use grep to search for the string in the file
  if grep -q "$string" "$file"; then
    return 0 # String found
  else
    return 1 # String not found
  fi
}

# ===== string_replace =====
# Description:
#     Replace all occurrences of a specified substring in a given string with another substring.
# Arguments:
#     $1 - The original string.
#     $2 - The substring to be replaced.
#     $3 - The substring to replace with.
# Usage:
#     string_replace "original_string" "substring_to_replace" "substring_to_replace_with"
# Output:
#     Prints the modified string with the substring replaced.
string_replace() {
  local string="${1}"
  local substring_to_replace="${2}"
  local substring_to_replace_with="${3}"

  # Replace the substring in the string
  local result="${string//$substring_to_replace/$substring_to_replace_with}"

  # Return the result
  echo "$result"
}

# ===== string_contains =====
# Description:
#     Check if a given string contains a specified substring.
# Arguments:
#     $1 - The original string.
#     $2 - The substring to search for.
# Usage:
#     string_contains "original_string" "substring_to_search"
# Output:
#     Returns 0 (true) if the substring is found in the original string.
#     Returns 1 (false) if the substring is not found in the original string.
string_contains() {
  local string=$1
  local substring=$2

  # Check if the string contains the substring
  if [[ "$string" == *"$substring"* ]]; then
    return 0 # Substring found
  else
    return 1 # Substring not found
  fi
}

# ===== trim =====
# Description:
#     Remove leading and trailing whitespace from string
# Arguments:
#     $1 - String to be whitespace trimmed
# Usage:
#     trim " hello-world "
# Output:
#     Original string with leading and trailing whitespace if present i.e.
# Example:
#    > trim " hello-world "
#    hello-world
trim() {
  local var="$*"
  # remove leading whitespace characters
  var="${var#"${var%%[![:space:]]*}"}"
  # remove trailing whitespace characters
  var="${var%"${var##*[![:space:]]}"}"
  printf '%s' "$var"
}

# ===== string_replace_regex =====
# Description:
#     Replace a specified substring in a given string using regex.
# Arguments:
#     $1 - The original string.
#     $2 - The regex pattern to match the substring to replace.
#     $3 - The replacement string (use an empty string for removal).
# Usage:
#     string_replace_regex "original_string" "regex_pattern" "replacement_string"
# Output:
#     Prints the modified string with the substring replaced.
string_replace_regex() {
  local string=$1
  local regex_pattern=$2
  local replacement=$3

  # Replace the substring using sed
  local result
  result=$(echo "$string" | sed -E "s|$regex_pattern|$replacement|g")

  # Return the result
  echo "$result"
}

# ===== unique_array =====
# Description:
#     Filter out duplicate elements from an array and return a unique set of elements.
# Arguments:
#     $@ - The original array (passed as individual elements).
# Usage:
#     unique_array "element1" "element2" "element1" ...
# Output:
#     Prints the unique array with duplicate elements removed.
unique_array() {
  local array=("$@")
  local unique_array

  # Use sort and uniq to filter out duplicates
  # shellcheck disable=SC2207
  unique_array=($(echo "${array[@]}" | tr ' ' '\n' | sort | uniq))

  # Return the unique array
  echo "${unique_array[@]}"
}

# ===== join_by =====
# Description:
#     Use string ($1) as delimiter to join string in variable ($2)
# Arguments:
#     $1 - joining string
#     $2 - String able to be delimited by IFS variable (usually set to whitespace)
# Usage:
#     join_by $delimiter $fields
# Output:
#     print string of $fields (separated by whitespace) joined by $delimiter
#     else 1 aka false
join_by() {
  local delimiter=${1-} fields=${2-}
  if shift 2; then
    printf %s "$fields" "${@/#/$delimiter}"
  fi
}

# ===== array_2_file =====
# Description:
#     Write the contents of an array to a file, with each element on a new line.
# Arguments:
#     $1 - Name of the array variable (passed by reference).
#     $2 - Path to the output file.
# Usage:
#     my_array=("element1" "element2" "element3")
#     array_2_file my_array /path/to/output_file.txt
array_2_file() {
  local array_name=$1
  local file=$2

  local item
  # Ensure the file is empty before writing
  : >"$file" || {
    echo "Can't create file"
    return 1
  }

  # Use eval to indirectly reference the array
  eval "local -a array=(\"\${${array_name}[@]}\")"

  for item in "${array[@]}"; do
    echo "$item" >>"$file"
  done
}
