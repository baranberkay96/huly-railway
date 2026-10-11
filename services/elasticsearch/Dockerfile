# Elasticsearch for Huly on Railway.
# huly-selfhost runs elasticsearch:7.14.2 and installs the ingest-attachment
# plugin on every start; this image uses the last 7.x line (7.17, same API,
# security fixes) and installs the plugin at build time.
# Starts as root only to fix ownership of the Railway volume, then drops to the
# elasticsearch user (uid 1000).
ARG ELASTICSEARCH_VERSION=7.17.28
FROM elasticsearch:${ELASTICSEARCH_VERSION}

RUN bin/elasticsearch-plugin install --batch ingest-attachment

USER root
COPY --chmod=0755 railway-start.sh /usr/local/bin/railway-start.sh

ENTRYPOINT ["/usr/local/bin/railway-start.sh"]
CMD ["eswrapper"]
