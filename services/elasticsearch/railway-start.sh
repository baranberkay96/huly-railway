#!/bin/bash
# Railway volumes are mounted root-owned and Elasticsearch refuses to run as
# root. Fix the data directory's ownership, then run the image's own entrypoint
# as uid 1000 (gid 0, as in the official image).
#
# The upstream entrypoint calls bin/elasticsearch-keystore by relative path to
# store ELASTIC_PASSWORD, so the working directory must stay ES_HOME (setpriv
# keeps it; plain chroot would reset it to / and skip the password silently).
set -euo pipefail

ES_HOME=/usr/share/elasticsearch
DATA_DIR="${ES_HOME}/data"

mkdir -p "$DATA_DIR"
rm -rf "${DATA_DIR}/lost+found"
chown -R 1000:0 "$DATA_DIR"
chmod 1777 /tmp

cd "$ES_HOME"
exec setpriv --reuid=1000 --regid=0 --clear-groups env HOME="$ES_HOME" \
  /usr/local/bin/docker-entrypoint.sh "$@"
