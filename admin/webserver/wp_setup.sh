#!/bin/bash
#
# WordPress activation script
#
# This script will configure Nginx with the domain
# provided by the user and offer the option to set up
# LetsEncrypt as well.
#
# This script was derived from created by DigitalOcean
# at https://github.com/digitalocean/droplet-1-clicks/blob/master/wordpress-22-04/files/root/wp_setup.sh
# and adapted original bash template script from Kyle Smith
#

# Exit on error
set -e

# Throw error if undefined variable used
set -u

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

    WordPress activation script

    This script will configure Nginx with the domain
    provided by the user and offer the option to set up
    LetsEncrypt as well.

# How to Use:
    # in ${SCRIPT_DIR}
    ./$0 <...>

# Inputs:
    --env-file:
        the configuration file for reading default staging environment configuration information

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
  declare -xg WEB_SERVICE_NAME="webserver"
  declare -xg environment_file="${WORKSPACE}/.env"
  declare -xg WORDPRESS_ADMIN_EMAIL
  declare -xg WORDPRESS_ADMIN_USER
  declare -xg WORDPRESS_ADMIN_PASSWORD
  declare -xg wordpress_blog_title
  # shellcheck disable=SC2155
  declare -xg temp_dir=$(mktemp -d)

  echo "Temporary directory created: ${temp_dir}"

  # Parse options
  while (($#)); do
    case "${1}" in
    --env-file)
      shift
      environment_file="${1}"
      ;;
    -h | --help | help)
      __script_help
      exit
      ;;

    esac
    shift
  done

  info "---------------------------------------------------------------------"
  info "environment_file:                          ${environment_file}"
  info "---------------------------------------------------------------------"
}

# __script_init (optional)
#       Initialize and validate the scripts environment.  This stage runs after
#       __script_parse_opts, so global variables set by parse_opts will be
#       available here.
#       This stage is useful for ensuring build tools are present, and ensuring
#       the necessary environment variables are set.
__script_init() { # Optional
  log INFO "Initializing $0 ..."
  local confirmation
  local dkc_exec="docker compose exec"
  local built_cmd
  local exec_cmd
  local database_docker_ip
  local sideload_wordpress_setup_script="help_wp_setup.sh"

  echo "This script will adjust the WordPress installation into"
  echo "Your docker containers existing docker container's ${WEBSERVER_ROOT}"
  echo "for wordpress by reading information needed from the other containers"
  echo "in the virtual network setup by docker compose needed for the wp-cli"
  echo "to function properly ."
  echo "--------------------------------------------------"
  echo "This setup requires a domain name to be in the .env file."
  echo "If you do not have one yet, you may cancel this setup, press Ctrl+C."
  echo "This script will run again on your next login"
  echo "--------------------------------------------------"
  # echo "Enter the domain name for your new WordPress site."
  # echo "(ex. example.org or test.example.org) do not include www or http/s"
  # echo "--------------------------------------------------"

  # if applicable, configure wordpress to use mysql dbaas
  if [ -e "${environment_file}" ]; then
    # grab all the data from the password file
    info "Loading environment installed configurations server from ${environment_file} ..."
    . "${environment_file}"

    # wait for db to become available
    info "Waiting for your database to become available (this may take a few minutes)"
    info "If this take too much time you may need to cancel over +5 min then, press Ctrl+C."
    while ! mysqladmin ping -h "${DOMAIN_NAME}" -P "${DATABASE_PORT}" --silent; do
      printf .
      sleep 2
    done
    echo -e "\nDatabase available!\n"

    # update the wp-config.php with stored credentials
    echo "#!/bin/sh" >"${temp_dir}/${sideload_wordpress_setup_script}"
    {
      __build_sed_replace DB_USER "${DATABASE_USER}"
      __build_sed_replace DB_NAME "${DATABASE_NAME}"
      __build_sed_replace DB_PASSWORD "${DATABASE_PASSWORD}"
      __build_sed_replace DB_HOST "${CONTAINER_NAME}-database"
    } >>"${temp_dir}/${sideload_wordpress_setup_script}"

    # add required SSL flag
    if [ -e "${WORKSPACE}/.enable_ssl_after_first_time_bring_up_complete" ]; then
      if ! grep -q "MYSQLI_CLIENT_SSL" "${WEBSERVER_ROOT}/wp-config.php"; then
        # add required SSL flag
        echo "echo \"/** Connect to MySQL cluster over SSL **/\" >>${WEBSERVER_ROOT}/wp-config.php" >>"${temp_dir}/${sideload_wordpress_setup_script}"
        echo "echo \"define( 'MYSQL_CLIENT_FLAGS', MYSQLI_CLIENT_SSL );\" >>${WEBSERVER_ROOT}/wp-config.php" >>"${temp_dir}/${sideload_wordpress_setup_script}"
      else
        info "MYSQLI_CLIENT_SSL is already defined in ${WEBSERVER_ROOT}/wp-config.php"
      fi
    fi

    info "Going to execute on wordpress docker container the following ... $(cat "${temp_dir}/${sideload_wordpress_setup_script}")"

    # Turn on extra verbosity for easier debugging
    set -x
    docker compose cp \
      "${temp_dir}/${sideload_wordpress_setup_script}" \
      "wordpress:${WEBSERVER_ROOT}/${sideload_wordpress_setup_script}"

    ${dkc_exec} wordpress chmod 755 "${WEBSERVER_ROOT}/${sideload_wordpress_setup_script}"
    ${dkc_exec} wordpress "${WEBSERVER_ROOT}/${sideload_wordpress_setup_script}"
    ${dkc_exec} wordpress rm "${WEBSERVER_ROOT}/${sideload_wordpress_setup_script}"
    set +x
  fi

  info "Now we will create your new admin user account for WordPress"
  info "and we will also prompt for server blog title. "

  # Get user prompt user information till properly given non-empty input
  prompt_user_for_wordpress_admin_account() {
    while [ -z "${WORDPRESS_ADMIN_EMAIL-}" ]; do
      echo -en "\n"
      read -rp "Your Email Address: " WORDPRESS_ADMIN_EMAIL
    done

    while [ -z "${WORDPRESS_ADMIN_USER-}" ]; do
      echo -en "\n"
      read -rp "Username: " WORDPRESS_ADMIN_USER
    done

    while [ -z "${WORDPRESS_ADMIN_PASSWORD-}" ]; do
      echo -en "\n"
      read -s -rp "Password: " WORDPRESS_ADMIN_PASSWORD
      echo -en "\n"
    done

    while [ -z "${wordpress_blog_title-}" ]; do
      echo -en "\n"
      read -rp "Blog Title: " wordpress_blog_title
    done
  }

  prompt_user_for_wordpress_admin_account

  while true; do
    echo -en "\n"
    info "Note: admin and title details will be prompted for again if dismissed. "
    read -rp "Is the information correct? [Y/n] " confirmation
    confirmation=${confirmation,,}
    if [[ "${confirmation}" =~ ^(yes|y)$ ]] || [ -z "${confirmation}" ]; then
      break
    else
      unset WORDPRESS_ADMIN_EMAIL
      unset WORDPRESS_ADMIN_USER
      unset WORDPRESS_ADMIN_PASSWORD
      unset wordpress_blog_title

      prompt_user_for_wordpress_admin_account
    fi
  done

  info "Ready to add admin user ..."
}

# __script_exec
#       Execute the script! This function receives no arguments and it assumes
#       the environment is fully configured before entering __script_exec. This
#       architecture enforces good script writing practices and reduces script
#       boilerplate for error handling.
__script_exec() { # Required
  local wp_cli
  local default_theme
  local default_themes

  # FIXME: this need to be done differently with a script I think
  # follow instructions on https://www.digitalocean.com/community/tutorials/how-to-install-wordpress-with-docker-compose
  # echo -en "\n\n\n"
  # echo "Next, you have the option of configuring LetsEncrypt to secure your new site.  Before doing this, be sure that you have pointed your domain or subdomain to this server's IP address.  You can also run LetsEncrypt certbot later with the command 'certbot --apache'"
  # echo -en "\n\n\n"
  # read -rp "Would you like to use LetsEncrypt (certbot) to configure SSL(https) for your new site? (y/n): " yn
  # case $yn in
  # [Yy]*)
  #   certbot --nginx
  #   echo "WordPress has been enabled at https://${DOMAIN_NAME}  Please open this URL in a browser to complete the setup of your site."
  #   ;;
  # [Nn]*)
  #   echo "Skipping LetsEncrypt certificate generation"
  #   ;;
  # *) echo "Please answer y or n." ;;
  # esac

  info "Completing the configuration of WordPress ..."

  # echo the command to the user
  set -x
  wp_cli="docker compose run --rm wordpress-cli"

  info "Performing core setup ... Setting title, admin-user, url, etc ..."
  ${wp_cli} core install \
    --allow-root \
    --path="${WEBSERVER_ROOT}" \
    --title="${wordpress_blog_title}" \
    --url="${DOMAIN_NAME}" \
    --admin_email="${WORDPRESS_ADMIN_EMAIL}" \
    --admin_password="${WORDPRESS_ADMIN_PASSWORD}" \
    --admin_user="${WORDPRESS_ADMIN_USER}"

  # NOTE: make a script to create users. Accidentally deleted user during testing. Leaving here for now
  # ${wp_cli} user create \
  #   "${WORDPRESS_ADMIN_USER}" "${WORDPRESS_ADMIN_EMAIL}" --role=administrator --user_pass="${WORDPRESS_ADMIN_PASSWORD}"

  # Select the permalink structure for your website. Including the %postname% tag makes links easy to understand,
  # and can help your posts rank higher in search engines.
  info "Set the permalink structure for your website. ..."
  ${wp_cli} option update permalink_structure "/%postname%/" --skip-themes --skip-plugins ||
    error "failed to install set permalink structure through wp-cli ..."

  info "Set default timezone, timeformat, start of the week information ..."
  ${wp_cli} option update timezone_string "America/Detroit" ||
    error "failed to setup timezone to Detroit through wp-cli ..."
  ${wp_cli} option update time_format "g:i A" ||
    error "failed to setup time format to look like \"2:15 PM\" through wp-cli ..."
  ${wp_cli} option update start_of_week 0 ||
    error "failed to set start of the week to be Sunday through wp-cli ..."

  info "Activating Hello-Dolly. It is not just a plugin, it symbolizes the hope and enthusiasm of an entire generation summed up in two words sung most famously by Louis Armstrong:"
  info "\"Hello, Dolly\". When activated you will randomly see a lyric from Hello, Dolly in the upper right of your admin screen on every page."
  info "And if you want to remove it, SHAME on you ..."
  ${wp_cli} plugin activate hello ||
    error "failed to activate hello-dolly and symbolizes the hope and enthusiasm so SHAME on those who delete it ..."

  # # Remove old default themes ...
  # default_themes=(twentytwentyfive twentytwentyfour twentytwentythree twentytwentytwo)
  # for default_theme in "${default_themes[@]}"; do
  #   info "Removing default themes (${default_themes[*]}) ..."
  #   ${wp_cli} theme delete --allow-root "${default_theme}" ||
  #     error "failed to delete theme ${default_theme} through wp-cli ..."
  # done

  # # Remove default posts, widgets, comments etc.
  # info "Removing default posts, widgets, comments etc ..."
  # ${wp_cli} site empty --allow-root --yes ||
  #   error "failed to remove default posts, widgets, comments etc through wp-cli ..."

  # # FIXME: TODO: need to install fail2ban on host or in a docker to proper make this actually meaningful
  # (
  #   ${wp_cli} plugin install wp-fail2ban --allow-root --path="${WEBSERVER_ROOT}" &&
  #     ${wp_cli} plugin activate wp-fail2ban --allow-root --path="${WEBSERVER_ROOT}"
  # ) || error "failed to install and activate fail2ban through wp-cli ..."

  set +x
}

# __script_succeed (optional)
#       If __script_exec succeeds, __script_succeed is evaluated.  This can be
#       used to provide feedback to the user about the success, or trigger
#       post-script-success logic
__script_succeed() { # Optional
  ok "$0 succeeded!: Installation complete. Access your new WordPress site in a browser to continue."
}

# __script_failed (optional)
#       If __script_exec fails, __script_failed is evaluated.  This can be used
#       to provide feedback to the user about the failure and trigger
#       post-script-failed logic.
__script_failed() { # Optional
  error "Could not execute $0 successfully"
  exit 1
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
  # info "Cleaning up potential dirty state ..."
  unset environment_file
  unset WORDPRESS_ADMIN_EMAIL
  unset WORDPRESS_ADMIN_USER
  unset WORDPRESS_ADMIN_PASSWORD
  unset wordpress_blog_title

  rm -rf "${temp_dir}"

  unset temp_dir
}

# Example Output:
#   sed -i "s/define(\s*'DB_NAME'\s*,\s*\(.*\)\s*);/define( 'DB_NAME', 'user' );/g" /root/workspace/wp-config.php
__build_sed_replace() {
  local variable_name=$1
  local new_value=$2
  local output_file=${3:-$WEBSERVER_ROOT/wp-config.php}
  local _match_pattern
  local _replace_sting
  _match_pattern="define(\s*'${variable_name}'\s*,\s*\(.*\)\s*);"
  _replace_sting="define( '${variable_name}' , '${new_value}' );"
  echo "sed -i \"s~${_match_pattern}~${_replace_sting}~g\" '${output_file}'"
}

trap __script_cleanup EXIT

__script_parse_opts "${@}"
__script_init
__script_exec
