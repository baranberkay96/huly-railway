# One-shot Huly owner bootstrap for Railway, on the official tool image
# (the same image huly-selfhost's run-tool.sh uses for `create-account`).
ARG HULY_VERSION=v0.7.426
FROM hardcoreeng/tool:${HULY_VERSION}

COPY railway-init.mjs /usr/src/app/railway-init.mjs

CMD ["node", "/usr/src/app/railway-init.mjs"]
