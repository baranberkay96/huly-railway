# NOTICE — Huly v0.7 All-in-One Team Workspace

## Software deployed (not redistributed)

| Component | Source | License |
|---|---|---|
| Huly platform services and tool | `hardcoreeng/*:v0.7.426` — https://github.com/hcengineering/platform | EPL-2.0 |
| HulyPulse | `hardcoreeng/service_hulypulse:0.1.29` — https://github.com/hcengineering/platform (`foundations/hulypulse`) | EPL-2.0 |
| CockroachDB | `cockroachdb/cockroach:v24.2.10` | CockroachDB Software License (`/licenses/LICENSE` in the image): production use requires a License Key from Cockroach Labs; telemetry may not be disabled without one |
| Redpanda | `redpandadata/redpanda:v24.3.18` | Business Source License 1.1 (Redpanda Community Edition) |
| Elasticsearch + ingest-attachment plugin | `elasticsearch:7.17.28` | Elastic License 2.0 / SSPL-1.0 (7.x default distribution) |
| Caddy | `caddy:2.11.7-alpine` | Apache-2.0 |

This template is a community template. It is not affiliated with or endorsed by Hardcore Engineering (Huly).

## Upstream files checked (2026-10-11)

- `hcengineering/huly-selfhost` (main, last commit 2026-09-29, EPL-2.0): `compose.yml`, `.template.huly.conf` (`HULY_VERSION=v0.7.426`), `.huly.nginx` (routes), `setup.sh` (secrets, CockroachDB/Redpanda defaults), `run-tool.sh` (`create-account`), `ARCHITECTURE_OVERVIEW.md`, `MIGRATION.md`, `README.md` (sign-up, HulyPulse, optional services).
- `hcengineering/platform` tag `v0.7.426`: `foundations/server/packages/s3/src/index.ts` (S3 adapter: `rootBucket`, `allowPresign`, client addressing), `foundations/server/packages/server-storage/src/starter.ts` (`STORAGE_CONFIG` parsing with `URLSearchParams`), `foundations/hulypulse/README.md`.
- Image entrypoints: `cockroachdb/cockroach:v24.2.10` `/cockroach/cockroach.sh` (first-start certificate, database and user creation), `redpandadata/redpanda:v24.3.18` `/entrypoint.sh`, `hardcoreeng/tool:v0.7.426` command help.

## Adapted material

- **hcengineering/huly-selfhost** — EPL-2.0 (Copyright Hardcore Engineering Inc.). Service list, environment variables, proxy routes (`services/proxy/Caddyfile` re-expresses the routes of `.huly.nginx` for Caddy) and the CockroachDB/Redpanda settings follow the official compose. `services/init/railway-init.mjs` runs the same `create-account` tool command as `run-tool.sh`. To the extent these files are derived from EPL-2.0 material, they are provided under EPL-2.0.
- `services/elasticsearch/railway-start.sh` and `services/cockroach/railway-cockroach.sh` were written for this template set.

## Not used

- `_upstream/vipulasri__huly-caddy-railway`, `_upstream/gridalpha__huly-railway`, `_upstream/vipulasri__kafka-railway` (no license, all rights reserved) and the market templates `huly-1`, `huly-workspace`: read for comparison only; nothing copied. All prose is original.
