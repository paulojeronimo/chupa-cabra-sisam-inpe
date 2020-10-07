#!/usr/bin/env bash
set -eou pipefail

cd "$(dirname "$0")"
source config.sh 2>&- || source config.sample.sh
docker push $DOCKER_IMAGE_NAME:$DOCKER_IMAGE_VERSION
