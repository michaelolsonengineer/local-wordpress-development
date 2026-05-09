# local-wordpress-development

A Docker-based local WordPress development environment with full CI/CD for DigitalOcean deployments.

## Features

- **One-command setup** via `wporchestrator` — installs dependencies, brings up containers, configures WordPress
- **Production DB restore** — import UpdraftPlus backups, auto-detect table prefix, rewrite URLs, fetch custom fonts
- **PR Preview Environments** — ephemeral DigitalOcean Droplets spun up per pull request, destroyed on PR close
- **SSL support** via Let's Encrypt (certbot) for production deployments
- **Non-interactive / CI mode** — `--yes` flag skips all prompts for automated runs

---

## Prerequisites

All dependencies are installed automatically by `./wporchestrator install_dependencies` on Ubuntu/Debian.

Manual install if preferred:

- [Docker](https://docs.docker.com/) + [Docker Compose plugin](https://docs.docker.com/compose/)
- `yq` — `sudo apt-get install -y yq` (Ubuntu 24.04+) or `snap install yq`
- `mysql-client` — `sudo apt-get install -y mysql-client`
- `git`, `curl`, `wget`, `jq` — `sudo apt-get install -y git curl wget jq`

---

## Quick Start (Local Development)

```bash
# 1. Clone the repo
git clone https://github.com/michaelolsonengineer/local-wordpress-development
cd local-wordpress-development

# 2. Configure environment
cp env.example .env
# Edit .env with your credentials (DOMAIN_NAME, DATABASE_*, WORDPRESS_ADMIN_*, etc.)

# 3. First-time bring-up: installs deps, starts containers, runs WordPress setup
./wporchestrator first-time-bring-up
```

WordPress will be available at `http://<DOMAIN_NAME>` (or `http://localhost` for local dev).

---

## wporchestrator Commands

| Command                                | Description                                                          |
| -------------------------------------- | -------------------------------------------------------------------- |
| `first-time-bring-up [--yes]`          | Install deps, start containers, run WordPress setup                  |
| `install_dependencies`                 | Install system packages (Docker, mysql-client, yq, etc.)             |
| `wp-setup [--yes]`                     | Run WordPress configuration (title, admin user, plugins, permalinks) |
| `restore-from-backup <file>`           | Restore an UpdraftPlus `.db.gz` backup, fix URLs, fetch fonts        |
| `fix-urls`                             | Reset `siteurl`/`home` to localhost after a production DB restore    |
| `enable-ssl-after-first-time-bring-up` | Obtain Let's Encrypt certs and switch site to HTTPS                  |
| `logs`                                 | Tail logs from all Docker Compose services                           |
| `nuke`                                 | Destroy all containers and volumes (**destructive**)                 |

`--yes` / `--non-interactive` — skips all interactive prompts; requires credentials set in `.env`.

---

## Production DB Restore

```bash
./wporchestrator restore-from-backup '/path/to/backup_2026-04-26-db.gz'
```

This will:

1. Copy the backup into the database container
2. Import it (directly via `mysql`, bypassing WP-CLI TLS issues with MySQL 8)
3. Auto-detect and write the table prefix to `.env`
4. Rewrite production domain URLs to `http://localhost` in `options` and `postmeta`
5. Download any custom fonts referenced in `postmeta`
6. Create/update the local admin user from `.env` credentials
7. Report the AIOS custom login slug if All-In-One Security is active

---

## Enabling SSL (Production)

```bash
# After first-time-bring-up with a real domain pointed at the server:
./wporchestrator enable-ssl-after-first-time-bring-up
```

Requires `PRODUCTION_DOMAIN` set in `.env`.

---

## CI/CD — GitHub Actions

Four workflows are included in `.github/workflows/`:

### `deploy-preview.yml` — PR Preview Environments

- Triggers on pull requests to `main` or `develop`
- Creates an ephemeral DigitalOcean Droplet named `pr-<N>` (Ubuntu 24.04, Docker pre-installed)
- Clones the branch, writes a minimal `.env`, runs `./wporchestrator first-time-bring-up --yes`
- Comments the live preview URL on the PR
- Destroys the Droplet when the PR is closed (`delete-preview.yml`)

### `deploy-app.yml` — Deploy to Production Droplet

- Triggers on push to `main` or `develop`
- SSHes into `DROPLET_HOST`, pulls latest, runs `docker compose up -d`

### `deploy-image.yml` — Build & Push Docker Image

- Builds a custom WordPress image, pushes to DigitalOcean Container Registry
- SSHes into Droplet, pulls new image, restarts services

### `delete-preview.yml` — Destroy PR Preview

- Triggers when a PR is closed
- Finds and destroys the `pr-<N>` Droplet via `doctl`

### Required GitHub Secrets

| Secret                      | Description                                               |
| --------------------------- | --------------------------------------------------------- |
| `DIGITALOCEAN_ACCESS_TOKEN` | DO personal access token                                  |
| `DO_SSH_KEY_FINGERPRINT`    | Fingerprint of SSH key registered in DO account           |
| `DROPLET_SSH_KEY`           | Private key matching `DO_SSH_KEY_FINGERPRINT`             |
| `DROPLET_USER`              | SSH user on the Droplet (default: `root`)                 |
| `DEPLOY_PATH`               | Path on Droplet to clone repo (default: `/srv/wordpress`) |
| `DO_REGISTRY_NAME`          | DO Container Registry name (for `deploy-image.yml`)       |
| `DATABASE_USER`             |                                                           |
| `DATABASE_PASSWORD`         |                                                           |
| `DATABASE_ROOT_PASSWORD`    |                                                           |
| `WORDPRESS_ADMIN_USER`      |                                                           |
| `WORDPRESS_ADMIN_PASSWORD`  |                                                           |
| `WORDPRESS_ADMIN_EMAIL`     |                                                           |

`DROPLET_HOST` is **not** required upfront — the bootstrap job creates a Droplet on first run and prints the IP.

---

## Troubleshooting

- **Stop local MySQL** before bringing up containers — it conflicts with the database container:
  `sudo systemctl stop mysql`

- **Do not edit docker-compose.yml while containers are running** — bring the stack down first.

- **Useful Docker commands:**
  ```bash
  docker compose ps                        # show running services
  docker compose logs <service>            # view logs for a service
  docker compose down                      # stop and remove containers
  docker volume prune                      # remove unused volumes
  ```

---

## Acknowledgments

- Originally derived from [Wazoo's local-wordpress-development](https://github.com/wazooinc/local-wordpress-development)
- [How To Install WordPress With Docker Compose](https://www.digitalocean.com/community/tutorials/how-to-install-wordpress-with-docker-compose) — DigitalOcean tutorial
- [Adding SSL to WordPress](https://www.youtube.com/watch?v=HH4s3x1PiA4) — Let's Encrypt + nginx setup
- [mkcert](https://github.com/FiloSottile/mkcert) — self-signed certs for local HTTPS
