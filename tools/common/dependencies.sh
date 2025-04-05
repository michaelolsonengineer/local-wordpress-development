#!/bin/bash

# Exit on error
set -e

# Throw error if undefined variable used
set -u

source "${TOOLS_COMMON_DIR:-.}/constants.sh"
#------------------------------------------------------------------------------

# Ensure basic packages are installed
#   curl: transfers data
#   git: Branch and repo management
#   pip3: python install manager
#   jq: JSON processor
#   yq: YAML processor
# Usage: install_basic_packages
install_basic_packages() {
  log INFO "Checking basic packages..."
  local install_basic_group=false
  local install_curl=""
  local install_wget=""
  local install_git=""
  local install_pip3=""
  local install_jq=""
  local install_yq=""

  if ! is_installed "curl"; then
    install_curl="curl"
    install_basic_group=true
  fi

  if ! is_installed "wget"; then
    install_wget="wget"
    install_basic_group=true
  fi

  if ! is_installed "git"; then
    install_git="git"
    install_basic_group=true
  fi

  if ! is_installed "pip3"; then # check if pip is installed for python3 ("any" version will work)
    install_pip3="python3-pip"
    install_basic_group=true
  fi

  if ! is_installed "jq"; then
    install_jq="jq"
    install_basic_group=true
  fi

  if ! is_installed "yq"; then
    install_jq="yq"
    install_basic_group=true
  fi

  if [ "${install_basic_group}" = true ]; then
    log INFO "Installing necessary basic packages"
    # shellcheck disable=SC2086
    sudo apt update && sudo apt install -y --no-install-recommends \
      ${install_curl} \
      ${install_wget} \
      ${install_git} \
      ${install_pip3} \
      ${install_jq} \
      ${install_yq}
  fi
}

#------------------------------------------------------------------------------
# Ensure necessary Docker dependency packages are installed
#   apt-transport-https: lets the package manager transfer files and data over https
#   ca-certificates:lets the web browser and system check security certificates
#   curl: transfers data
#   software-properties-common: adds scripts to manage the software
# Usage: install_docker_dependencies
install_docker_dependencies() {
  log INFO "Checking Docker dependency packages..."
  local install_dependencies_group=false
  local install_apt_transport_https=""
  local install_ca_certificates=""
  local install_software_properties_common=""

  if ! is_installed "apt-transport-https"; then
    install_apt_transport_https="apt-transport-https"
    install_dependencies_group=true
  fi

  if ! is_installed "ca-certificates"; then
    install_ca_certificates="ca-certificates"
    install_dependencies_group=true
  fi

  if ! is_installed "software-properties-common"; then
    install_software_properties_common="software-properties-common"
    install_dependencies_group=true
  fi

  if [ "$install_dependencies_group" = true ]; then
    log INFO "Installing necessary Docker dependency packages"
    # shellcheck disable=SC2086
    sudo apt update && sudo apt install -y --no-install-recommends \
      ${install_apt_transport_https} \
      ${install_ca_certificates} \
      ${install_software_properties_common}
  fi
}

# Sets up environment to run Docker
# See https://docs.docker.com/engine/install/ubuntu/ for more information
# Usage: setup_docker
setup_docker() {
  local docker_apt_repo
  local docker_apt_search_pattern="https://download.docker.com/linux/ubuntu"
  install_docker_dependencies

  # Add Docker's official GPG key
  if [ ! -e "/etc/apt/keyrings/docker.asc" ]; then
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
  fi

  # Add the repository to Apt sources:
  docker_apt_repo="deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable"

  # Check if the repository is already added and add it if not
  if ! grep -r -q -F --include "*.list" "${docker_apt_search_pattern}" /etc/apt/sources.list.d/ 2>/dev/null; then
    log INFO "Adding Docker repository to Apt sources"
    sudo add-apt-repository "${docker_apt_repo}"
    sudo apt update
    # docker suggests using the following command to add the repository, but using linux official command above
    # echo "${docker_apt_repo}" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  else
    log INFO "Docker repository already exists in apt-repository sources"
  fi

  install_docker

  # Add user to docker group so docker commands can be run without using sudo
  sudo usermod -aG docker "${USER}"

  if ! verify_docker_permission; then
    echo "Could not complete dependency installation script due to docker permission issues."
    echo "Please read the INFO message above for details on how to resolve this."
  fi

  # Verify docker properly installed and running
  if ! docker --version >/dev/null; then
    echo "Docker is not set up properly, please report this error"
  fi
}

# Ensure necessary Docker packages are installed
#   docker-ce: Docker - community edition
#   docker-ce-cli: Command line interface for Docker CE
#   containerd.io: Daemon that manages runtime environment for containers
#   docker-buildx-plugin: Docker CLI plugin for extended build capabilities with BuildKit
#   docker-compose-plugin: Docker CLI plugin for extended compose capabilities with ComposeKit
# Usage: install_docker
install_docker() {
  log INFO "Checking Docker packages..."
  local install_docker_group=false
  local install_docker_ce=""
  local install_docker_ce_cli=""
  local install_containerd_io=""
  local install_docker_buildx_plugin=""
  local install_docker_compose_plugin=""

  if ! is_installed "docker-ce"; then
    install_docker_ce="docker-ce"
    install_docker_group=true
  fi

  if ! is_installed "docker-ce-cli"; then
    install_docker_ce_cli="docker-ce-cli"
    install_docker_group=true
  fi

  if ! is_installed "containerd.io"; then
    install_containerd_io="containerd.io"
    install_docker_group=true
  fi

  if ! is_installed "docker-buildx-plugin"; then
    install_docker_buildx_plugin="docker-buildx-plugin"
    install_docker_group=true
  fi

  if ! is_installed "docker-compose-plugin"; then
    install_docker_compose_plugin="docker-compose-plugin"
    install_docker_group=true
  fi

  if [ "${install_docker_group}" = true ]; then
    log INFO "Installing necessary Docker packages"
    # shellcheck disable=SC2086
    sudo apt update && sudo apt install -y --no-install-recommends \
      ${install_docker_ce} \
      ${install_docker_ce_cli} \
      ${install_containerd_io} \
      ${install_docker_buildx_plugin} \
      ${install_docker_compose_plugin}
    log INFO "Errors encountered while processing docker-ce is expected." \
      "This is remedied at the end of the script."
  fi
}

# Ensure necessary webapp packages are installed
#   mysql-client: MySQL client
#   certbot: EFF's tool to obtain certs from Let's Encrypt
#   wp-cli: Command line interface for WordPress
# Usage: install_webapp_packages
install_webapp_packages() {
  log INFO "Checking webapp packages..."
  local install_webapp_group=false
  local install_mysql_client=""
  local install_certbot=""

  if ! is_installed "mysqladmin"; then
    local install_mysql_client="mysql-client"
    install_webapp_group=true
  fi

  if ! is_installed "certbot"; then
    install_certbot="certbot"
    install_webapp_group=true
  fi

  if [ ! -f "${TOOLS_COMMON_DIR}/../../admin/webserver/wp" ]; then
    echo "Sets up wordpress cli"
    wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -O "${TOOLS_COMMON_DIR}/../../admin/webserver/wp"
    chmod +x "${TOOLS_COMMON_DIR}/../../admin/webserver/wp"
    # sudo cp "${TOOLS_COMMON_DIR}/../../admin/webserver/wp" /usr/bin/wp
    # sudo chown root:root /usr/bin/wp
  fi

  if [ "${install_webapp_group}" = true ]; then
    log INFO "Installing necessary Webapp packages"
    # shellcheck disable=SC2086
    sudo apt update && sudo apt install -y --no-install-recommends \
      ${install_mysql_client} \
      ${install_certbot}
  fi
}

# Ensure miscellaneous (dev/networking tools) packages are installed
#   golang: Go programming language
# Usage: install_miscellaneous_packages
install_miscellaneous_packages() {
  log INFO "Checking miscellaneous packages..."
  local install_miscellaneous_group=false
  local install_golang=""

  if ! is_installed "golang"; then
    install_golang="golang"
    install_miscellaneous_group=true
  fi

  # netcat-traditional
  # iputils-ping
  # iproute2
  # tree
  # tmux
  # nano
  # nmap
  # ncdu
  # htop
  # iftop
  # iotop
  # strace
  # lsof
  # tcpdump
  # vim
  # dns_utils
  # net_tools
  # ack
  # less
  # html2text

  if [ "${install_miscellaneous_group}" = true ]; then
    log INFO "Installing miscellaneous packages"
    # shellcheck disable=SC2086
    sudo apt update && sudo apt install -y --no-install-recommends \
      ${install_golang}
  fi
}
