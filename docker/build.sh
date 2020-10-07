#!/usr/bin/env bash
set -eou pipefail

cd "`dirname "$0"`"
source ./config.sh 2>&- || source ./config.sample.sh
mkdir -p files-to-add
for file in $FILES_TO_ADD
do
	! [[ $file =~ '|' ]] || {
		new_name=$(cut -d'|' -f2 <<< $file)
		file=$(cut -d'|' -f1 <<< $file)
		cp $FILES_DIR/$file files-to-add/$new_name
		continue
	}
	cp $FILES_DIR/$file files-to-add/
done
sed "s/_ENTRYPOINT_/$ENTRYPOINT/g" Dockerfile.template > Dockerfile
docker build -t $DOCKER_IMAGE_NAME:$DOCKER_IMAGE_VERSION .
