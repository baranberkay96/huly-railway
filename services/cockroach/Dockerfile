# CockroachDB for Huly on Railway (same release line as huly-selfhost: latest-v24.2).
# Adds only a wrapper that keeps data and certificates on the single Railway volume.
ARG COCKROACH_VERSION=v24.2.10
FROM cockroachdb/cockroach:${COCKROACH_VERSION}

COPY --chmod=0755 railway-cockroach.sh /cockroach/railway-cockroach.sh

ENTRYPOINT ["/cockroach/railway-cockroach.sh"]
CMD []
