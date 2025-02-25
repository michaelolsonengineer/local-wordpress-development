# local-wordpress-development

Another Docker Configuration for Local WordPress development

## Installation - In progress

#### Prerequisites

-   Install Git
    -   if Linux and debian/ubuntu
        -   `sudo apt install git`
    -   if Windows
        -   [Git SCM](https://git-scm.com/downloads/win)
        -   [Github Desktop](https://desktop.github.com/download/) (Recommended)
-   Install [Docker](https://docs.docker.com/)
-   Install [Docker Compose](https://docs.docker.com/compose/)
-   Install [mkcert](https://github.com/FiloSottile/mkcert)
    -   If Ubuntu/Debian,
        -   `sudo apt install golang` is needed to build to install mkcert

#### Initialization

-   Clone [this repository](https://github.com/michaelolsonengineer/local-wordpress-development)
-   Copy env.example to .env on host environment at root of workspace of desired server
-   Edit newly created .env with desired secret credentials
-   NOTE: if local development only, then create self-signed certificates

#### Build/Run

-   if first time
    -   `docker compose up --build`
-   else
    -   `docker compose up`

## Troubleshooting and Helpful Tips

-   Do not edit docker configurations while docker is running.

    -   Bring system down before editing. It can cause docker compose to have difficulty finding containers for example.

-   Make sure to stop any local running databases that might conflict with databases defined in the docker compose files.

    -   i.e. `sudo systemctl stop mysql`

#### Know some basic docker commands

-   `docker container ls`
    -   list containers
-   `docker volume ls`
    -   list volumes
-   `docker log <CONTAINER_NAME>`
    -   show system logs till now of CONTAINER_NAME
-   `docker ps -a`
    -   show any existing running containers
-   `docker volume prune`
    -   remove any dangling volumes if existing
-   `docker rm $(docker ps -a -f status=exited -q)`
    -   remove any exited containers if existing
-   If you are needing to really nuke, know how to do that with docker and/or make the scripts
    -   `docker volume rm $DIRECTORY_NAME_wordpress $DIRECTORY_NAME_dbdata`
    -   i.e `docker volume rm wp_wordpress wp_dbdata`

## Acknowledgments

-   Repo originally started from - [Wazoo's Github Repo of Local Wordpress development](https://github.com/wazooinc/local-wordpress-development)

    -   Going off of material from [Docker Setup for Local WordPress Development](https://www.youtube.com/watch?v=GG2k-La5t3or) for step-by-step guide
    -   And [Adding SSL to Wordpress](https://www.youtube.com/watch?v=HH4s3x1PiA4) (aka pt2) which will need a [self-signed certificates tool](https://github.com/FiloSottile/mkcert) local development

-   And mixing with [How To Install WordPress With Docker Compose](https://www.digitalocean.com/community/tutorials/how-to-install-wordpress-with-docker-compose) another step-by-step for refresher

-   and my own docker experience since it had been some 3+ years since I have worked with docker and web stuff
