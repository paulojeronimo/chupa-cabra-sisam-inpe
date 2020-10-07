#!/usr/bin/env bash
set -eou pipefail

cd "`dirname "$0"`"
source ./config.sh 2>&- || source ./config.sample.sh
mkdir -p data
docker run -it --rm -v "$PWD"/data:/data $DOCKER_IMAGE_NAME:$DOCKER_IMAGE_VERSION "$@"
