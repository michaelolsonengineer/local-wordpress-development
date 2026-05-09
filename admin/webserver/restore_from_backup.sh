#!/bin/bash
#
# restore_from_backup.sh
#
#   Restores a WordPress site from an UpdraftPlus backup set onto localhost.
#
#   Steps performed:
#     1. Copy backup file(s) into the container's updraft directory
#     2. Import the DB directly via the database container (avoids WP-CLI/MariaDB TLS issues)
#     3. Detect non-default table prefix and update .env + restart wordpress container
#     4. Rewrite all production domain references → http://localhost (options + postmeta)
#     5. Download missing custom font files (tries production, falls back to 1001fonts)
#     6. Create / update the local admin user from .env credentials
#     7. Report custom AIOS login slug if rename-login is active
#
#   Usage:
#     bash restore_from_backup.sh --env-file <path-to-.env> <backup-dir-or-file>
#

# set -e: Exit on error
# set -u: Throw error if undefined variable used
set -e -u

# shellcheck disable=SC2155
declare -xg SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../tools/common/constants.sh"
source "${SCRIPT_DIR}/../../tools/common/general_utils.sh"

# ------------------------------------------------------------------------------

__script_help() {
  cat <<EOM
===== $0 ====

# Description:
    Restore a WordPress site from an UpdraftPlus backup set onto localhost.

# Usage:
    $0 --env-file <path-to-.env> <backup-dir-or-file>

# Arguments:
    --env-file <path>   Path to the .env file (required)
    <backup-path>       A single backup file (*.db.gz) or a directory containing
                        a full UpdraftPlus backup set
    --fix-urls          Only fix siteurl/home to http://localhost and report
                        the AIOS custom login slug. Useful after a manual
                        UpdraftPlus UI restore.

EOM
  exit 1
}

__script_parse_opts() {
  declare -xg _backup_path=""
  declare -xg _do_fix_urls="false"

  while (($#)); do
    case "${1}" in
    --env-file)
      shift
      WS_ENV_FILE="${1}"
      ;;
    --fix-urls)
      _do_fix_urls="true"
      ;;
    -h | --help | help)
      __script_help
      ;;
    *)
      _backup_path="${1}"
      ;;
    esac
    shift
  done

  if [ -z "${WS_ENV_FILE:-}" ] || [ ! -f "${WS_ENV_FILE}" ]; then
    error "--env-file is required and must point to an existing file."
    exit 1
  fi

  if [ "${_do_fix_urls}" = "false" ] && [ -z "${_backup_path}" ]; then
    error "No backup path provided. Use --fix-urls or supply a backup file/directory."
    __script_help
  fi
}

__script_init() {
  # Load environment variables
  # shellcheck disable=SC1090
  . "${WS_ENV_FILE}"

  if [ "${_do_fix_urls}" = "false" ] && [ ! -e "${_backup_path}" ]; then
    error "Backup path does not exist: ${_backup_path}"
    exit 1
  fi
}

__script_exec() {
  if [ "${_do_fix_urls}" = "true" ]; then
    _fix_urls
    return
  fi

  _copy_backup_files
  _import_db
  _post_import_tasks
  _ensure_local_admin
}

# ------------------------------------------------------------------------------
# _fix_urls
#   Reset siteurl and home to http://localhost.
#   Also detects and reports the custom AIOS login slug if rename-login is active.
#   Can be invoked standalone via: restore_from_backup.sh --env-file .env --fix-urls
# ------------------------------------------------------------------------------
_fix_urls() {
  local prefix="${WORDPRESS_TABLE_PREFIX:-wp_}"
  local db_user="${DATABASE_USER}"
  local db_pass="${DATABASE_PASSWORD}"
  local db_name="${DATABASE_NAME}"

  info "Fixing siteurl and home to http://localhost (prefix: ${prefix}) ..."
  docker compose exec -T database mysql \
    -u"${db_user}" -p"${db_pass}" "${db_name}" 2>/dev/null \
    -e "UPDATE ${prefix}options
        SET option_value='http://localhost'
        WHERE option_name IN ('siteurl','home');" || true

  local login_slug
  login_slug=$(docker compose exec -T database mysql \
    -u"${db_user}" -p"${db_pass}" "${db_name}" 2>/dev/null \
    -e "SELECT option_value FROM ${prefix}options WHERE option_name='aio_wp_security_configs';" \
    | grep -oP '"aiowps_login_page_slug";s:\d+:"\K[^"]+' || true)

  if [ -n "${login_slug}" ]; then
    warning "AIOS rename-login is active — wp-login.php returns 404 by design."
    info "  --> Login at: http://localhost/${login_slug}"
  else
    info "  --> Login at: http://localhost/wp-login.php"
  fi
  info "Done."
}

# ------------------------------------------------------------------------------
# _copy_backup_files
#   Copy all backup files into the container's updraft directory.
# ------------------------------------------------------------------------------
_copy_backup_files() {
  local updraft_dir="/var/www/html/wp-content/updraft"

  info "Copying backup files into container at ${updraft_dir} ..."
  if [ -d "${_backup_path}" ]; then
    for f in "${_backup_path}"/*; do
      [ -f "${f}" ] || continue
      info "  Copying: ${f}"
      run docker compose cp "${f}" "wordpress:${updraft_dir}/$(basename "${f}")"
    done
  else
    info "  Copying: ${_backup_path}"
    run docker compose cp "${_backup_path}" "wordpress:${updraft_dir}/$(basename "${_backup_path}")"
  fi

  # Fix permissions so www-data can read the files
  docker compose exec -T wordpress chown -R www-data:www-data "${updraft_dir}" || true
  info "Backup files copied."
}

# ------------------------------------------------------------------------------
# _import_db
#   Find the .db.gz (or already-decompressed SQL) in the container and import it
#   directly through the database container, bypassing the WP-CLI/MariaDB TLS issue.
# ------------------------------------------------------------------------------
_import_db() {
  local updraft_dir="/var/www/html/wp-content/updraft"
  local base
  base=$(basename "${_backup_path}")

  # If a .gz was supplied, decompress it inside the container first
  local sql_file
  if [[ "${base}" == *.gz ]]; then
    local sql_base="${base%.gz}"
    info "Decompressing ${base} inside container ..."
    docker compose exec -T wordpress sh -c \
      "gunzip -kf '${updraft_dir}/${base}'"
    sql_file="${updraft_dir}/${sql_base}"
  else
    sql_file="${updraft_dir}/${base}"
  fi

  info "Importing database from ${sql_file} ..."
  docker compose exec -T database mysql \
    -u"${DATABASE_USER}" -p"${DATABASE_PASSWORD}" "${DATABASE_NAME}" \
    < <(docker compose exec -T wordpress cat "${sql_file}") 2>/dev/null
  info "Database imported."
}

# ------------------------------------------------------------------------------
# _post_import_tasks
#   1. Detect table prefix → update .env + restart wordpress if needed
#   2. Rewrite production domain → localhost in options and postmeta
#   3. Download missing custom font files
#   4. Report custom AIOS login URL
# ------------------------------------------------------------------------------
_post_import_tasks() {
  local db_user="${DATABASE_USER}"
  local db_pass="${DATABASE_PASSWORD}"
  local db_name="${DATABASE_NAME}"

  # --- Detect table prefix ---
  local detected_prefix
  detected_prefix=$(docker compose exec -T database mysql \
    -u"${db_user}" -p"${db_pass}" "${db_name}" 2>/dev/null \
    -e "SHOW TABLES LIKE '%options';" \
    | grep -v "Tables_in" | grep -oP "^[a-zA-Z0-9_]+(?=options)" | head -1 || true)

  if [ -n "${detected_prefix}" ] && [ "${detected_prefix}" != "wp_" ]; then
    info "Detected non-default table prefix: ${detected_prefix}"
    if grep -q "^WORDPRESS_TABLE_PREFIX=" "${WS_ENV_FILE}"; then
      sed -i "s|^WORDPRESS_TABLE_PREFIX=.*|WORDPRESS_TABLE_PREFIX=${detected_prefix}|" "${WS_ENV_FILE}"
    else
      printf '\n# Match production DB table prefix\nWORDPRESS_TABLE_PREFIX=%s\n' "${detected_prefix}" >> "${WS_ENV_FILE}"
    fi
    info "Restarting wordpress container to apply new table prefix ..."
    run docker compose up -d --force-recreate --no-deps wordpress
    sleep 3
    # Reload env after .env change
    # shellcheck disable=SC1090
    . "${WS_ENV_FILE}"
  fi

  local prefix="${detected_prefix:-wp_}"

  # --- Detect production domain before overwriting it ---
  local prod_domain
  prod_domain=$(docker compose exec -T database mysql \
    -u"${db_user}" -p"${db_pass}" "${db_name}" 2>/dev/null \
    -e "SELECT option_value FROM ${prefix}options WHERE option_name='siteurl';" \
    | grep -v "option_value" | grep -v "localhost" | head -1 \
    | sed 's|https\?://||;s|/.*||' || true)

  # --- Fix siteurl / home ---
  info "Setting siteurl and home to http://localhost ..."
  docker compose exec -T database mysql \
    -u"${db_user}" -p"${db_pass}" "${db_name}" 2>/dev/null \
    -e "UPDATE ${prefix}options
        SET option_value='http://localhost'
        WHERE option_name IN ('siteurl','home');" || true

  # --- Rewrite production domain in postmeta (e.g. custom font URLs) ---
  if [ -n "${prod_domain}" ]; then
    info "Rewriting '${prod_domain}' → 'localhost' in postmeta ..."
    docker compose exec -T database mysql \
      -u"${db_user}" -p"${db_pass}" "${db_name}" 2>/dev/null \
      -e "UPDATE ${prefix}postmeta
          SET meta_value = REPLACE(meta_value, 'https://${prod_domain}', 'http://localhost')
          WHERE meta_value LIKE '%${prod_domain}%';
          UPDATE ${prefix}postmeta
          SET meta_value = REPLACE(meta_value, 'http://${prod_domain}',  'http://localhost')
          WHERE meta_value LIKE '%${prod_domain}%';" || true
  fi

  # --- Fonts ---
  _fetch_custom_fonts "${prefix}" "${db_user}" "${db_pass}" "${db_name}"

  # --- AIOS custom login slug ---
  local login_slug
  login_slug=$(docker compose exec -T database mysql \
    -u"${db_user}" -p"${db_pass}" "${db_name}" 2>/dev/null \
    -e "SELECT option_value FROM ${prefix}options WHERE option_name='aio_wp_security_configs';" \
    | grep -oP '"aiowps_login_page_slug";s:\d+:"\K[^"]+' || true)

  if [ -n "${login_slug}" ]; then
    warning "AIOS rename-login is active — wp-login.php returns 404 by design."
    info "  --> Login at: http://localhost/${login_slug}"
  else
    info "  --> Login at: http://localhost/wp-login.php"
  fi
}

# ------------------------------------------------------------------------------
# _fetch_custom_fonts
#   Finds all custom font file URLs in postmeta, checks if files are present
#   locally, and downloads them (production first, then 1001fonts as fallback).
# ------------------------------------------------------------------------------
_fetch_custom_fonts() {
  local prefix="${1}" db_user="${2}" db_pass="${3}" db_name="${4}"
  local uploads_dir="${WORKSPACE}/src/uploads"

  info "Checking custom font files ..."

  local font_urls
  font_urls=$(docker compose exec -T database mysql \
    -u"${db_user}" -p"${db_pass}" "${db_name}" 2>/dev/null \
    -e "SELECT meta_value FROM ${prefix}postmeta WHERE meta_key IN ('fonts-data','fonts-face');" \
    | grep -oP "https?://[^\"']+\.(otf|ttf|woff2?|eot)[^\"']*" | sort -u || true)

  if [ -z "${font_urls}" ]; then
    info "  No custom font URLs found."
    return
  fi

  while IFS= read -r url; do
    local rel_path="${url#*wp-content/uploads/}"
    local local_path="${uploads_dir}/${rel_path%%\?*}"
    local filename
    filename=$(basename "${local_path}")
    local dest_dir
    dest_dir=$(dirname "${local_path}")

    if [ -f "${local_path}" ]; then
      info "  Font already present: ${filename}"
      continue
    fi

    info "  Missing: ${filename} — attempting download ..."
    sudo mkdir -p "${dest_dir}"

    # 1) Try downloading directly from the URL (works if production is live)
    if curl -fsSL -o "${local_path}" "${url}" 2>/dev/null; then
      sudo chown "$(id -u):$(id -g)" "${local_path}"
      info "    Downloaded from production: ${filename}"
      continue
    fi

    # 2) Fall back to 1001fonts.com
    #    Derive slug: "AlphonseMucha" → "alphonse-mucha"
    local slug
    slug=$(basename "${filename%.*}" \
      | sed 's/\([A-Z]\)/-\1/g; s/^-//; s/[_ ]/-/g' \
      | tr '[:upper:]' '[:lower:]')
    local zip_url="https://www.1001fonts.com/download/${slug}.zip"
    local tmp_zip="/tmp/${slug}.zip"

    info "    Trying 1001fonts: ${zip_url}"
    if curl -fsSL -o "${tmp_zip}" "${zip_url}" 2>/dev/null; then
      local ext="${filename##*.}"
      local extracted
      extracted=$(unzip -Z1 "${tmp_zip}" 2>/dev/null | grep -i "\.${ext}$" | head -1 || true)
      if [ -n "${extracted}" ]; then
        unzip -p "${tmp_zip}" "${extracted}" | sudo tee "${local_path}" > /dev/null
        sudo chown "$(id -u):$(id -g)" "${local_path}"
        info "    Installed from 1001fonts: ${filename}"
      else
        warning "    .${ext} not found in 1001fonts zip for '${slug}'. Install manually into: ${dest_dir}/"
      fi
      rm -f "${tmp_zip}"
    else
      warning "    Could not download '${filename}'. Install manually into: ${dest_dir}/"
    fi
  done <<< "${font_urls}"
}

# ------------------------------------------------------------------------------
# _ensure_local_admin
#   Create or update the local admin user defined in .env so there is always
#   a known-credential login available after a production DB restore.
# ------------------------------------------------------------------------------
_ensure_local_admin() {
  local wp="docker compose run --rm wordpress-cli wp --allow-root --path=${WEBSERVER_ROOT}"
  local user="${WORDPRESS_ADMIN_USER:-admin}"
  local pass="${WORDPRESS_ADMIN_PASSWORD:-changeme123}"
  local email="${WORDPRESS_ADMIN_EMAIL:-admin@localhost}"

  if [ -z "${user}" ] || [ -z "${pass}" ]; then
    warning "WORDPRESS_ADMIN_USER or WORDPRESS_ADMIN_PASSWORD not set in .env — skipping local admin creation."
    return
  fi

  info "Ensuring local admin user '${user}' exists ..."
  if ${wp} user get "${user}" --field=login 2>/dev/null | grep -q "^${user}$"; then
    info "  User '${user}' found — updating password and role ..."
    run ${wp} user update "${user}" --user_pass="${pass}" --role=administrator
    run ${wp} user update "${user}" --user_email="${email}"
  else
    info "  User '${user}' not found — creating ..."
    run ${wp} user create "${user}" "${email}" --role=administrator --user_pass="${pass}"
  fi
  info "  Local admin ready — user: '${user}'  password: '${pass}'"
}

# ------------------------------------------------------------------------------

__script_succeed() {
  ok "$0 succeeded — visit http://localhost to verify."
}

__script_failed() {
  error "$0 failed. Check docker compose logs for details."
}

__script_cleanup() {
  if [ $? -eq 0 ]; then
    __script_succeed
  else
    __script_failed
  fi
}

trap __script_cleanup EXIT

__script_parse_opts "${@}"
__script_init
__script_exec
