#!/usr/bin/env bash
set -eou pipefail

ENTRYPOINT=${ENTRYPOINT:-queimadas-downloader.sh}
FILES_DIR=..
FILES_TO_ADD="chupa-cabra.sh|$ENTRYPOINT all_ufs.txt"
DOCKER_IMAGE_NAME=${DOCKER_IMAGE_NAME:-paulojeronimo/sisam-inpe-${ENTRYPOINT%.sh}}
DOCKER_IMAGE_VERSION=${DOCKER_IMAGE_VERSION:-latest}
