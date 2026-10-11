#!/bin/bash
# CockroachDB (single node, as in huly-selfhost) on one Railway volume.
#
# Upstream uses two volumes: cockroach-data and certs. Railway allows one per
# service, so the volume is mounted at /cockroach/persist and both directories
# live inside it; the paths the image's entrypoint expects become symlinks.
# Then the image's own entrypoint runs: on an empty data directory it creates
# the certificates, the database and the user with a password, exactly as upstream.
#
# Optional: COCKROACH_LICENSE_KEY (+ COCKROACH_ORGANIZATION) is applied as
# cluster settings once the node accepts SQL (see the CockroachDB license).
set -euo pipefail

PERSIST=/cockroach/persist
cd /cockroach

mkdir -p "$PERSIST"
rm -rf "${PERSIST}/lost+found"
mkdir -p "${PERSIST}/data" "${PERSIST}/certs"

for link in cockroach-data:data certs:certs; do
  name="${link%%:*}"; target="${PERSIST}/${link##*:}"
  if [ ! -L "/cockroach/${name}" ]; then
    rm -rf "/cockroach/${name}"
    ln -s "$target" "/cockroach/${name}"
  fi
done

apply_license() {
  local sql=(/cockroach/cockroach sql --certs-dir=/cockroach/certs --host=127.0.0.1)
  for _ in $(seq 1 120); do
    "${sql[@]}" -e 'SELECT 1' >/dev/null 2>&1 && break
    sleep 5
  done
  local org="${COCKROACH_ORGANIZATION:-}"
  local key="${COCKROACH_LICENSE_KEY}"
  if "${sql[@]}" -e "SET CLUSTER SETTING cluster.organization = '${org//\'/\'\'}'" \
                 -e "SET CLUSTER SETTING enterprise.license = '${key//\'/\'\'}'"; then
    echo "[railway-cockroach] license key applied"
  else
    echo "[railway-cockroach] WARNING: applying the license key failed (see the error above)"
  fi
}

if [ -n "${COCKROACH_LICENSE_KEY:-}" ]; then
  apply_license &
fi

exec /cockroach/cockroach.sh start-single-node \
  --accept-sql-without-tls \
  --cache="${COCKROACH_CACHE:-256MiB}" \
  --max-sql-memory="${COCKROACH_MAX_SQL_MEMORY:-256MiB}" \
  "$@"
