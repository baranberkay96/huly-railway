# Huly v0.7 All-in-One Team Workspace — Railway template spec

## Listing

| Field | Value |
|---|---|
| Name | **Huly v0.7 All-in-One Team Workspace** (version label `v0.7` = major.minor of a 0.x release, with Huly's own "v") |
| Description | Projects, chat and docs in one app. Open-source Linear + Slack alternative. (75 chars) |
| Category | Other |
| Tags | huly, project-management, issue-tracker, team-chat, documents, linear-alternative, slack-alternative |
| Icon | https://cdn.jsdelivr.net/gh/hcengineering/platform@v0.7.426/dev/prod/public/huly/icon-256.png |
| User input at deploy | **`HULY_OWNER_EMAIL`** (init) — login of the owner account. Everything else is generated. |

Listing description kept (exactly 75 characters, the limit). Projects/issues, chat (channels, direct messages, typing indicators via HulyPulse) and collaborative documents are all part of the deployed stack. Video calls (Love/LiveKit), e-mail notifications, AI and third-party integrations are optional upstream services and not included (see Open questions).

## Base market templates (reference only)

Both market templates have no license, so they were read for ideas and nothing was copied.

- **`huly-1`** (Huly s0.7.330, 61 projects / 10 active): CockroachDB in `--insecure` mode, a third-party Kafka repo with a public TCP proxy, **MinIO with `minioadmin`**, Elasticsearch 7.14 without the ingest-attachment plugin, floating `latest-v24.2`, open sign-up, no healthchecks, Caddy from a third-party repo.
- **`huly-workspace`** (v0.7.426, 2 projects): Postgres instead of CockroachDB (not the upstream database), `apache/kafka`, Railway Bucket via `s3|…&rootBucket=…` with a `sed`-based partial URL encoding, open sign-up. The `rootBucket` idea (all workspaces as folders of one bucket) is used here, verified against Huly's S3 adapter source.

## Pinned versions

| Service | Image | Tag | Checked |
|---|---|---|---|
| front, account, transactor, collaborator, workspace, fulltext, rekoni, stats, kvs | `hardcoreeng/<name>` (`rekoni-service`, `hulykvs`) | `v0.7.426` (2026-07-03) | 2026-10-11 |
| hulypulse | `hardcoreeng/service_hulypulse` | `0.1.29` | 2026-10-11 |
| init (built from `services/init`) | `hardcoreeng/tool` | `v0.7.426` | 2026-10-11 |
| cockroach (built from `services/cockroach`) | `cockroachdb/cockroach` | `v24.2.10` (= upstream `latest-v24.2`) | 2026-10-11 |
| redpanda | `redpandadata/redpanda` | `v24.3.18` (upstream pins `v24.3.6`; same minor, later patches) | 2026-10-11 |
| elastic (built from `services/elasticsearch`) | `elasticsearch` | `7.17.28` (upstream `7.14.2`; same 7.x API) + `ingest-attachment` | 2026-10-11 |
| proxy (built from `services/proxy`) | `caddy` | `2.11.7-alpine` | 2026-10-11 |
| Bucket | Railway Bucket | – | – |

`v0.7.426` is the version pinned by `hcengineering/huly-selfhost` (main, `.template.huly.conf`, last updated 2026-09-29; `MIGRATION.md`: "v0.7.426 — No changes required"). Newer `v0.7.432` images exist but are not yet the self-host recommendation.

**Upgrades:** read huly-selfhost's `MIGRATION.md` for the target version, then change the tag on all `hardcoreeng/*` services together (and `HULY_VERSION` in `services/init/Dockerfile`, `DESKTOP_UPDATES_CHANNEL` on front) and redeploy. The workspace service upgrades workspaces on start. Never jump from 0.6 to 0.7 in place (upstream migration guide).

## Architecture

```
Internet ──HTTPS──▶ proxy (Caddy :8080)
                      /            → front :8080          (UI, /files, config.json)
                      /_accounts   → account :3000        (login, workspaces)
                      /_transactor, /eyJ… → transactor :3333 (websocket RPC)
                      /_collaborator → collaborator :3078 (Y.js documents, websocket)
                      /_rekoni     → rekoni :4004         (text extraction)
                      /_stats      → stats :4900
                      /_pulse      → hulypulse :8099 /ws  (presence, typing)
   workspace (creates/upgrades workspaces) · fulltext (indexing) · kvs (key-value store for integrations)
   init (one-shot: creates the owner account)
        │
   cockroach (CockroachDB, data + certs on one volume) · redpanda (Kafka API, volume)
   elastic (Elasticsearch 7.17 + ingest-attachment, volume) · Bucket (all files, one folder per workspace)
```

All services talk over Railway's private network (`<service>.railway.internal`). Browsers only reach the proxy; Huly's public URLs (`ACCOUNTS_URL`, `COLLABORATOR_URL`, `TRANSACTOR_URL`'s public half, …) all point to the proxy's domain.

**Object storage.** Huly's `s3` storage adapter with `rootBucket` keeps every workspace as a folder of one Railway Bucket (virtual-hosted style, which the adapter's AWS SDK client uses by default — matches Railway). `STORAGE_CONFIG` is built at start from the `S3_*` variables with `encodeURIComponent` (Huly parses it with `URLSearchParams`, so `+`, `/`, `=` or `&` in keys would otherwise break it). `allowPresign=false`: files are streamed by front instead of redirecting browsers to presigned bucket URLs (no CORS setup needed).

**Sign-up.** Upstream leaves sign-up open, so anyone who finds the URL can create accounts and workspaces. Here `DISABLE_SIGNUP=true` on account and front, and the one-shot `init` service creates the owner account with Huly's own tool command (`create-account`, as in huly-selfhost's `run-tool.sh`), verifies it by logging in, and exits. The owner signs in, creates workspaces and invites people with invite links (verified: `signUp` is refused, `createWorkspace` works for the owner). Idempotent: an existing account is never changed.

### Deviations from upstream compose (and why)

- nginx on the host → **Caddy service** with the same routes (one public domain per Railway service; path routing to several services needs a proxy).
- MinIO (`pgsty/silo`) → **Railway Bucket** (`s3` adapter + `rootBucket`).
- CockroachDB: data and certificates on one volume (`/cockroach/persist`, symlinked to the paths the image expects); `--cache`/`--max-sql-memory` set to 256 MiB (default is 25% of the host's memory each); optional license key applied from variables. Same secure mode with password auth over plain SQL (`--accept-sql-without-tls`) as upstream. Telemetry left at the default (the license does not allow disabling it without a key that permits it).
- Redpanda: advertised on the Railway private domain, listeners on `[::]` (IPv4 + IPv6, verified), `--memory 1G` (Seastar would size itself to the host), runs as root (`RAILWAY_RUN_UID=0`) for the root-owned volume. No external listeners (nothing outside the project needs Kafka).
- Elasticsearch 7.17.28 instead of 7.14.2 (same major, security fixes), plugin installed at build time instead of on every start, security on with a generated password (credentials in `FULLTEXT_DB_URL`/`ELASTIC_URL`; verified that fulltext indexes with authentication).
- kvs and hulypulse listen on `::` (`HULY_BIND_HOST`); upstream default `0.0.0.0` is IPv4 only.
- HulyPulse enabled (commented out upstream; in-memory backend as upstream recommends for single-node installs) for presence and typing indicators.
- workspace gets `FULLTEXT_URL` (it logs that it needs it to clean the search index of deleted workspaces).
- `LOVE_ENDPOINT` not set (the Love video service is not included).

## Services

Image services marked "storage" use this **start command** (with their own final `exec`), which builds `STORAGE_CONFIG` and starts the image's normal command:

```
/bin/sh -c 'q() { node -p "encodeURIComponent(process.argv[1])" "$1"; }; export STORAGE_CONFIG="s3|$S3_ENDPOINT?accessKey=$(q "$S3_ACCESS_KEY")&secretKey=$(q "$S3_SECRET_KEY")&region=$(q "$S3_REGION")&rootBucket=$(q "$S3_BUCKET")&allowPresign=false"; exec node ./bundle.js'
```

Storage services also get `S3_ENDPOINT=${{Bucket.ENDPOINT}}`, `S3_ACCESS_KEY=${{Bucket.ACCESS_KEY_ID}}`, `S3_SECRET_KEY=${{Bucket.SECRET_ACCESS_KEY}}`, `S3_BUCKET=${{Bucket.BUCKET}}`, `S3_REGION=${{Bucket.REGION}}`. `SERVER_SECRET`/`SECRET`/`HULY_TOKEN_SECRET` everywhere reference `${{transactor.SERVER_SECRET}}`; `DB_URL` references `${{cockroach.DB_URL}}`; `QUEUE_CONFIG` is `${{redpanda.RAILWAY_PRIVATE_DOMAIN}}:9092`. `{host}` below = `${{proxy.RAILWAY_PUBLIC_DOMAIN}}`. All Huly app services: no volume, no public domain, restart ALWAYS (they start before CockroachDB/Redpanda/Elasticsearch are built and reconnect), 1 replica.

| Service | Source | Start command | Healthcheck | Key variables (all with descriptions in template.json) |
|---|---|---|---|---|
| **proxy** | repo `/services/proxy` (Caddy 2.11.7) | image default | `/_healthz` (300 s), public domain → 8080 | `PORT=8080`, `FRONT_HOST`, `ACCOUNT_HOST`, `TRANSACTOR_HOST`, `COLLABORATOR_HOST`, `REKONI_HOST`, `STATS_HOST`, `PULSE_HOST` (= `${{svc.RAILWAY_PRIVATE_DOMAIN}}:port`), `MAX_UPLOAD_SIZE=100MB` |
| **front** | `hardcoreeng/front:v0.7.426` | storage, `exec node ./bundle.js` | `/` (900 s) | `PORT=8080`, `SERVER_PORT=8080`, `ACCOUNTS_URL=https://{host}/_accounts`, `ACCOUNTS_URL_INTERNAL`, `REKONI_URL`, `CALENDAR_URL`, `GMAIL_URL`, `TELEGRAM_URL`, `STATS_URL` (public, as upstream), `UPLOAD_URL=/files`, `ELASTIC_URL` (with credentials), `COLLABORATOR_URL=wss://{host}/_collaborator`, `PULSE_URL=https://{host}/_pulse`, `TITLE=Huly`, `DEFAULT_LANGUAGE=en`, `LAST_NAME_FIRST=true`, `DESKTOP_UPDATES_CHANNEL=0.7.426`, `DISABLED_FEATURES=auto-translate,mailboxes`, `DISABLE_SIGNUP=${{account.DISABLE_SIGNUP}}` |
| **account** | `hardcoreeng/account:v0.7.426` | storage, `exec node bundle.js` | – | `SERVER_PORT=3000`, `ACCOUNT_PORT=3000`, `TRANSACTOR_URL=ws://transactor…:3333;wss://{host}/_transactor`, `FRONT_URL`, `STATS_URL`, `ACCOUNTS_URL` (public), `MODEL_ENABLED=*`, `DISABLE_SIGNUP=true` |
| **transactor** | `hardcoreeng/transactor:v0.7.426` | storage, `exec node ./bundle.js` | – | `SERVER_SECRET=${{secret(64, hex)}}` (canonical), `SERVER_PORT=3333`, `FRONT_URL=https://{host}`, `ACCOUNTS_URL`, `FULLTEXT_URL`, `STATS_URL`, `PULSE_URL` (private), `LAST_NAME_FIRST=true` |
| **collaborator** | `hardcoreeng/collaborator:v0.7.426` | storage, `exec node bundle.js` | – | `COLLABORATOR_PORT=3078`, `ACCOUNTS_URL`, `STATS_URL` |
| **workspace** | `hardcoreeng/workspace:v0.7.426` | storage, `exec node bundle.js` | – | `ACCOUNTS_DB_URL`, `TRANSACTOR_URL`, `MODEL_ENABLED=*`, `ACCOUNTS_URL`, `STATS_URL`, `FULLTEXT_URL` |
| **fulltext** | `hardcoreeng/fulltext:v0.7.426` | storage, `exec node --expose-gc bundle.js` | – | `FULLTEXT_DB_URL=http://elastic:{password}@elastic…:9200`, `ELASTIC_INDEX_NAME=huly_storage_index`, `REKONI_URL`, `ACCOUNTS_URL`, `STATS_URL` |
| **rekoni** | `hardcoreeng/rekoni-service:v0.7.426` | image default | – | `SECRET`, `PORT=4004` |
| **stats** | `hardcoreeng/stats:v0.7.426` | image default | – | `SERVER_SECRET`, `PORT=4900` |
| **kvs** | `hardcoreeng/hulykvs:v0.7.426` | image default | – | `HULY_DB_CONNECTION`, `HULY_TOKEN_SECRET`, `HULY_BIND_HOST=::`, `HULY_BIND_PORT=8094` |
| **hulypulse** | `hardcoreeng/service_hulypulse:0.1.29` | image default | – | `HULY_TOKEN_SECRET`, `HULY_BIND_HOST=::`, `HULY_BIND_PORT=8099`, `HULY_BACKEND=memory`, `HULY_HEARTBEAT_TIMEOUT=60`, `HULY_LOG=info` |
| **init** | repo `/services/init` (`hardcoreeng/tool:v0.7.426` + `railway-init.mjs`) | image default | – | **`HULY_OWNER_EMAIL` (required)**, `HULY_OWNER_PASSWORD=${{secret(20, alnum)}}`, `HULY_OWNER_FIRST_NAME=Owner`, `HULY_OWNER_LAST_NAME=Admin`, `SERVER_SECRET`, `DB_URL`, `ACCOUNT_DB_URL`, `ACCOUNTS_URL` (private). Restart ON_FAILURE (10 retries): waits up to 15 min for the account service, then exits 0. |
| **cockroach** | repo `/services/cockroach` (`cockroachdb/cockroach:v24.2.10` + wrapper) | image default | – | Volume `/cockroach/persist`. `COCKROACH_DATABASE=defaultdb`, `COCKROACH_USER=selfhost`, `COCKROACH_PASSWORD=${{secret(32)}}`, `COCKROACH_CACHE=256MiB`, `COCKROACH_MAX_SQL_MEMORY=256MiB`, `COCKROACH_LICENSE_KEY` / `COCKROACH_ORGANIZATION` (optional, empty), `DB_URL=postgres://${{COCKROACH_USER}}:${{COCKROACH_PASSWORD}}@${{RAILWAY_PRIVATE_DOMAIN}}:26257/${{COCKROACH_DATABASE}}`. Restart ON_FAILURE (10). |
| **redpanda** | `redpandadata/redpanda:v24.3.18` | `/bin/sh -c "rm -rf /var/lib/redpanda/data/lost+found && exec rpk redpanda start --kafka-addr internal://[::]:9092 --advertise-kafka-addr internal://$RAILWAY_PRIVATE_DOMAIN:9092 --pandaproxy-addr internal://[::]:8082 --advertise-pandaproxy-addr internal://$RAILWAY_PRIVATE_DOMAIN:8082 --schema-registry-addr internal://[::]:8081 --rpc-addr 0.0.0.0:33145 --advertise-rpc-addr $RAILWAY_PRIVATE_DOMAIN:33145 --mode dev-container --smp 1 --memory $REDPANDA_MEMORY --reserve-memory 0M --default-log-level=info"` | – | Volume `/var/lib/redpanda/data`. `REDPANDA_MEMORY=1G`, `RAILWAY_RUN_UID=0`. Restart ON_FAILURE (10). |
| **elastic** | repo `/services/elasticsearch` (`elasticsearch:7.17.28` + ingest-attachment + wrapper) | image default | – | Volume `/usr/share/elasticsearch/data`. `discovery.type=single-node`, `xpack.security.enabled=true`, `ELASTIC_PASSWORD=${{secret(32)}}`, `ES_JAVA_OPTS=-Xms1g -Xmx1g`, `network.host=0.0.0.0`, `node.store.allow_mmap=false`, `bootstrap.memory_lock=false`, `ingest.geoip.downloader.enabled=false`, `xpack.ml.enabled=false`. Restart ON_FAILURE (10). |
| **Bucket** | Railway Bucket | – | – | Provides `BUCKET`, `ACCESS_KEY_ID`, `SECRET_ACCESS_KEY`, `REGION`, `ENDPOINT`. |

The full variable list with values and descriptions is in `template.json`.

## Improvements over market templates

| # | Change | Why |
|---|---|---|
| 1 | Upstream self-host version `v0.7.426` on every Huly image, upstream databases (CockroachDB + Redpanda + Elasticsearch) | `huly-1` runs an old staging build (`s0.7.330`); `huly-workspace` swaps in Postgres/Kafka. |
| 2 | Railway Bucket with `rootBucket` and correctly URL-encoded credentials; no MinIO | MinIO images are discontinued and the leader shipped `minioadmin`. |
| 3 | Sign-up closed; owner account created by a one-shot init with Huly's own tool | No stranger can claim the instance or create workspaces on it. |
| 4 | CockroachDB in secure mode with a generated password, certificates persisted, memory capped | Leader ran `--insecure` (any client on the network is root) and would size caches from the host's RAM. |
| 5 | Elasticsearch 7.17 with the ingest-attachment plugin baked in and a password | Attachment indexing works; no plugin download on each boot. |
| 6 | Redpanda on the private network only, IPv4+IPv6 listeners, memory-capped | Leader exposed Kafka through a public TCP proxy. |
| 7 | Caddy proxy with all upstream routes incl. `/eyJ…` transactor tokens and `/_pulse`, healthchecks on proxy and front | Websockets for transactor, collaborator and pulse verified (HTTP 101). |
| 8 | HulyPulse (presence, typing) and `FULLTEXT_URL` for workspace clean-up | More complete product, cleaner deletes. |
| 9 | Tested locally (arm64, IPv6-enabled network, S3 via a local SeaweedFS in virtual-hosted mode, secret key with `+/=` characters): owner bootstrap (idempotent), sign-up refused, workspace created in ≈3.5 s with its files in the bucket folder, 208 documents indexed in Elasticsearch with authentication, websocket upgrades through the proxy | Fewer surprises on the first Railway deploy. |

## First login

1. Deploy with your e-mail in `HULY_OWNER_EMAIL` (init service). Wait for front and proxy to turn healthy and for init's log line `owner account … created`.
2. Open the proxy's public URL and sign in with that e-mail and `HULY_OWNER_PASSWORD` (init → Variables). Create your first workspace.
3. Invite teammates from the workspace (invite link); they can sign up through the link even though public sign-up is off.
4. To allow open sign-up instead, set `DISABLE_SIGNUP=false` on account (front follows) and redeploy both.

## Scaling

- Huly's app services are stateless; the busiest are transactor (all websocket traffic), front and fulltext. Give them more memory/CPU first. Upstream runs one instance of each; this template does too.
- CockroachDB: raise `COCKROACH_CACHE`/`COCKROACH_MAX_SQL_MEMORY` with its memory. Elasticsearch: raise `ES_JAVA_OPTS` with its memory. Redpanda: `REDPANDA_MEMORY`.
- Huly recommends 4 vCPU / 16 GB for a single-server install; this template spreads that over services, so give the busy ones room as usage grows.

## Backups

Railway volume backups of cockroach (all data), elastic (search index, can be rebuilt) and redpanda (transient queues). Files are in the Bucket (no automatic Bucket backups on Railway). huly-selfhost also ships `backup-create.sh` / `backup-restore.sh` based on the tool image (`backup`, `backup-restore` commands); run the tool from the init service's shell with a target directory if you need workspace-level backups.

## Resource estimate

Railway prices: RAM $10/GB-month, vCPU $20/vCPU-month, volume $0.15/GB-month, Bucket $0.015/GB-month. Idle figures measured locally (arm64) with three workspaces.

| Service | Idle RAM | Typical RAM (10–30 users) | Typical CPU |
|---|---|---|---|
| transactor | 115 MB | 800 MB | 0.3 vCPU |
| front | 60 MB | 200 MB | 0.05 vCPU |
| account | 85 MB | 150 MB | 0.02 vCPU |
| collaborator | 95 MB | 300 MB | 0.05 vCPU |
| workspace | 130 MB | 300 MB | 0.05 vCPU |
| fulltext | 155 MB | 400 MB | 0.1 vCPU |
| rekoni | 55 MB | 300 MB | 0.05 vCPU |
| stats, kvs, hulypulse, proxy | 95 MB together | 200 MB | 0.03 vCPU |
| cockroach | 670 MB | 1.2 GB | 0.2 vCPU |
| redpanda (`--memory 1G`) | 240 MB | 500 MB | 0.05 vCPU |
| elastic (1 GB heap) | 1.4 GB | 1.6 GB | 0.1 vCPU |
| init | 0 (exits) | 0 | – |
| **Total** | **≈3.1 GB** (≈0.25 vCPU) | **≈6.0 GB** | **≈1.0 vCPU** |

- **Idle:** ≈ $31 RAM + $5 CPU + $0.5 volumes ≈ **$37/month**.
- **Typical:** ≈ $60 RAM + $20 CPU + $1.5 volumes (10 GB) + $0.15 Bucket ≈ **$82/month**.
- **Minimum plan:** Hobby (Elasticsearch alone exceeds Trial's 1 GB; 15 services). CockroachDB used 1.4 GB of disk after three workspaces, so watch Hobby's 5 GB volume limit; Pro for larger teams.

## Verification checklist

- [ ] Builds succeed: proxy, init, cockroach, elastic.
- [ ] cockroach log: `finished creating default user "selfhost"` on first boot, `restarted pre-existing node` after a redeploy; with a license key set, `[railway-cockroach] license key applied`.
- [ ] redpanda: `rpk cluster info` (service shell) lists the broker at `redpanda.railway.internal:9092`.
- [ ] init log: `owner account {email} created`; the service then shows as exited/completed.
- [ ] proxy healthy on `/_healthz`, front healthy on `/`.
- [ ] Sign in, create a workspace, create an issue and a document, edit the document in two browsers (collaborator), send a chat message (typing indicator via `/_pulse`).
- [ ] Attach a file → it appears in the Bucket under the workspace's folder (Railway → Bucket → Files) and downloads again.
- [ ] Search for a word from the document → result found (fulltext → Elasticsearch).
- [ ] Redeploy all services → data, files and login persist.

## Open questions

- **Railway Bucket compatibility** of Huly's S3 adapter (AWS SDK v3, virtual-hosted style, `HeadBucket`/`CreateBucket` on the root bucket tolerated) was verified only against a local S3 server; confirm with the attachment test above.
- **Not included** (optional upstream services, need extra configuration or external accounts): Love (video calls, needs LiveKit), mail (SMTP/SES; outbound SMTP needs Railway Pro), print, export, AI bot, GitHub, Telegram, Gmail and Google Calendar integrations. huly-selfhost's README describes each; they can be added as extra services from the same images.
- **CockroachDB licensing (important):** the `v24.2.10` image upstream pins (`latest-v24.2`) ships under the **CockroachDB Software License** (`/licenses/LICENSE` in the image): operating it without a License Key is allowed only for "Limited Non-Production Use", and Telemetry must not be disabled without a key that allows it. Production users need a key from Cockroach Labs (a free Enterprise tier exists for qualifying companies) and can set it in `COCKROACH_LICENSE_KEY` / `COCKROACH_ORGANIZATION`. This is a summary, not legal advice; review the license for your organisation. A market template runs Huly on PostgreSQL instead, but huly-selfhost only documents CockroachDB, so this template stays with upstream's database.
- **Redpanda dev-container mode** (as upstream) trades durability for low resource use; queue contents are transient for Huly, but a crash can lose in-flight indexing events (fixed by a fulltext reindex from the tool).
