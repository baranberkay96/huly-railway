# Reverse proxy for Huly on Railway: one public domain, path-based routing to the
# Huly services on the private network (replaces huly-selfhost's host nginx).
ARG CADDY_VERSION=2.11.7-alpine
FROM caddy:${CADDY_VERSION}

COPY Caddyfile /etc/caddy/Caddyfile
RUN caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile

EXPOSE 8080
