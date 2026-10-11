# Deploy and Host Huly with Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/huly-v07-all-in-one-team-workspace?referralCode=20H68q)

Huly is an open-source workspace that combines project tracking, team chat and collaborative documents, often compared to Linear, Slack and Notion. This community template deploys the full Huly v0.7 self-hosted stack on Railway behind one domain, with CockroachDB, Redpanda, Elasticsearch search, a Railway Bucket for files and an owner account created for you.

> **License note:** this stack runs CockroachDB, which is distributed under the CockroachDB Software License. Production use requires a license key from Cockroach Labs (free tiers exist for some organizations), and telemetry cannot be disabled without one. Set `COCKROACH_LICENSE_KEY` and `COCKROACH_ORGANIZATION` after deploying. Review the license terms before using this template in production.

## About Hosting Huly

Self-hosted Huly is a set of cooperating services: a front server for the web app, an account service, a transactor that handles every change over websockets, a collaborator for real-time document editing, a workspace service, full-text indexing with text extraction, and small stats, key-value and presence services. It stores data in CockroachDB, streams events through a Kafka-compatible broker, indexes content in Elasticsearch and keeps files in S3-compatible storage. This template runs each part as its own Railway service following the official huly-selfhost setup, routes everything through a Caddy proxy on one domain, stores files in a Railway Bucket, and closes public sign-up so only invited people can join.

## Common Use Cases

- Issue tracking with projects, sprints and boards for software teams
- Team chat with channels, threads and direct messages next to the work
- Shared documents and wikis edited together in real time
- Replacing Linear, Jira, Slack or Notion subscriptions with one self-hosted tool
- Keeping project data inside your own infrastructure

## Dependencies for Huly Hosting

- Huly v0.7.426 services (official `hardcoreeng/*` images)
- CockroachDB v24.2
- Redpanda v24.3 (Kafka API)
- Elasticsearch 7.17 with the ingest-attachment plugin
- Caddy 2.11 as the reverse proxy
- S3-compatible object storage (Railway Bucket)

### Deployment Dependencies

- huly-selfhost (official self-hosting setup this template follows): https://github.com/hcengineering/huly-selfhost
- Huly platform source and releases: https://github.com/hcengineering/platform
- CockroachDB Docker documentation: https://www.cockroachlabs.com/docs/stable/start-a-local-cluster-in-docker-linux
- Redpanda documentation: https://docs.redpanda.com/
- Railway Storage Buckets: https://docs.railway.com/storage-buckets

### Implementation Details

| Service | Image | Role |
|---|---|---|
| proxy | built from `services/proxy` (Caddy) | Public domain; routes `/`, `/_accounts`, `/_transactor`, `/_collaborator`, `/_rekoni`, `/_stats`, `/_pulse` |
| front | `hardcoreeng/front:v0.7.426` | Web app and file downloads |
| account | `hardcoreeng/account:v0.7.426` | Accounts, login, workspaces |
| transactor | `hardcoreeng/transactor:v0.7.426` | Real-time data API (websockets) |
| collaborator | `hardcoreeng/collaborator:v0.7.426` | Collaborative document editing |
| workspace | `hardcoreeng/workspace:v0.7.426` | Creates and upgrades workspaces |
| fulltext, rekoni | `hardcoreeng/fulltext`, `hardcoreeng/rekoni-service` | Search indexing and text extraction from files |
| stats, kvs, hulypulse | `hardcoreeng/stats`, `hardcoreeng/hulykvs`, `hardcoreeng/service_hulypulse` | Metrics, key-value store, presence and typing indicators |
| init | built from `services/init` (Huly tool image) | One-time creation of the owner account |
| cockroach | built from `services/cockroach` | Database (volume) |
| redpanda | `redpandadata/redpanda:v24.3.18` | Event streaming (volume) |
| elastic | built from `services/elasticsearch` | Search index (volume) |
| Bucket | Railway Bucket | Attachments, images and document content |

**First login:** enter your e-mail in `HULY_OWNER_EMAIL` when deploying. When the proxy and front are healthy and the init service has logged that the owner account was created, open the proxy's public URL and sign in with that e-mail and the generated `HULY_OWNER_PASSWORD` from the init service variables. Create a workspace, then invite your team with an invite link. Public sign-up is off; set `DISABLE_SIGNUP=false` on the account service and redeploy account and front to open it.

**Scaling:** Huly's application services are stateless. Give transactor, front and fulltext more memory and CPU first as your team grows, and raise the memory settings of CockroachDB (`COCKROACH_CACHE`, `COCKROACH_MAX_SQL_MEMORY`), Elasticsearch (`ES_JAVA_OPTS`) and Redpanda (`REDPANDA_MEMORY`) together with their service resources.

**Optional services:** video calls (Love with LiveKit), e-mail notifications, printing, exports, the AI assistant and the GitHub, Telegram, Gmail and Google Calendar integrations are separate upstream services and are not part of this template. The huly-selfhost README describes how to add each one. E-mail through SMTP needs Railway's Pro plan.

**CockroachDB license:** the CockroachDB release used by huly-selfhost is distributed under the CockroachDB Software License, which requires a license key from Cockroach Labs for production use (a free tier exists for qualifying companies). Set it in `COCKROACH_LICENSE_KEY` and `COCKROACH_ORGANIZATION` on the cockroach service, and review the license terms for your organisation.

**Versions:** all Huly images are pinned to `v0.7.426`, the version huly-selfhost recommends. Before upgrading, read huly-selfhost's `MIGRATION.md` for the target version, then change the tag on every Huly service together and redeploy.

### Why Deploy Huly on Railway?

Huly needs more than a dozen cooperating services, a database cluster, a message broker, a search engine and object storage. Railway runs them all in one project with private networking, persistent volumes, a managed bucket and HTTPS, so your team's workspace is up from one template and each part can be resized from the dashboard.
