# Nextcloud Fast Stack — PHP-FPM

[![Nextcloud](https://img.shields.io/badge/Nextcloud-33-0082C9?logo=nextcloud&logoColor=white)](https://hub.docker.com/_/nextcloud)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-17-4169E1?logo=postgresql&logoColor=white)](https://hub.docker.com/_/postgres)
[![Redis](https://img.shields.io/badge/Redis-7-DC382D?logo=redis&logoColor=white)](https://hub.docker.com/_/redis)
[![Caddy](https://img.shields.io/badge/Caddy-2-00ADD8?logo=caddy&logoColor=white)](https://hub.docker.com/_/caddy)

**Official images only. No custom builds. `docker pull` to update.**

PHP-FPM 8.3 · PostgreSQL 17 · Redis 7 · Caddy 2 · JIT enabled · ~100–150ms TTFB

Nextcloud runs **fully internally** on a Docker network — no ports exposed to
the host, no TLS config to wrestle with. How you connect to it from outside
your network is entirely up to you.

> Looking for the FrankenPHP variant (~50ms TTFB, single container, requires a build)?
> See [`../frankenphp/`](../frankenphp/README.md).

---

## How it works

```
docker compose up -d
         |
         v
  nextcloud_net (Docker bridge, internal)
  ├── nextcloud       PHP-FPM on :9000
  ├── nextcloud-caddy PHP proxy on :CADDY_PORT (default 8080)
  ├── nextcloud-cron  Background job runner (every 5 min)
  ├── nextcloud-db    PostgreSQL 17
  └── nextcloud-redis Redis 7
         |
         v
  You decide how to reach caddy:8080 from outside:
  Traefik / Caddy / Nginx / Tailscale / Cloudflare Tunnel / VPN / etc.
```

This stack is the baton. You carry it the last mile.

---

## Quick Start

**Prerequisites:** Docker Engine 24+ and Docker Compose v2

```bash
git clone https://github.com/snuffomega/nextcloud-fast-stack.git
cd nextcloud-fast-stack/fpm
cp .env.example .env
```

Edit `.env` — at minimum set:

```env
POSTGRES_PASSWORD=a-strong-db-password
NEXTCLOUD_ADMIN_PASSWORD=a-strong-admin-password
NEXTCLOUD_DOMAIN=cloud.yourdomain.com     # or LAN IP: 192.168.1.100
```

```bash
docker compose up -d
docker compose logs -f nextcloud-caddy
```

Nextcloud is now accessible on your Docker network at `http://nextcloud-caddy:8080`.
Point your reverse proxy of choice there.

**Port conflict?** If another container already uses 8080, change `CADDY_PORT` in `.env`.

---

## Updating

```bash
docker compose pull
docker compose up -d
docker exec -u www-data nextcloud php occ upgrade
docker exec -u www-data nextcloud php occ maintenance:mode --off
```

All images are official — `docker pull` fetches the latest minor/patch release within
the pinned major tag (e.g. `nextcloud:33-fpm-alpine` tracks 33.x).

---

## Unraid

See [UNRAID.md](UNRAID.md) for the full volume path reference.

Short version: create `/mnt/user/appdata/nextcloud/` subdirectories, then
replace the named volumes in `docker-compose.yml` with the bind-mount paths
from that file.

---

## Essential Post-Install

Run once after Nextcloud is accessible:

```bash
# Optimise file metadata indices (clears admin warnings)
docker exec -u www-data nextcloud php occ db:add-missing-indices

# Convert file cache IDs to bigint for future scale
docker exec -u www-data nextcloud php occ db:convert-filecache-bigint

# Confirm installation health
docker exec -u www-data nextcloud php occ status
```

---

## Background Jobs (Cron)

The `nextcloud-cron` service runs Nextcloud's background job processor every 5 minutes. It is required for:

- Activity feeds and notifications
- Share expiry and federated share syncing
- App background tasks (preview pre-generation, full-text search indexing, etc.)

Confirm it is running:

```bash
docker exec -u www-data nextcloud php occ background:cron
docker logs nextcloud-cron
```

Check **Admin → Basic settings** — the "Last cron job executed" timestamp should update within ~10 minutes of first deploy.

---

## Optional Tuning

**Enable Imaginary** (faster preview generation)\
Uncomment the `imaginary:` block in `docker-compose.yml`, restart, then add to `config/config.php`:
```php
'enabledPreviewProviders' => ['OC\Preview\Imaginary'],
'preview_imaginary_url'   => 'http://imaginary:9000',
```

**Verify JIT is active:**
```bash
docker exec nextcloud php -r "var_dump(opcache_get_status()['jit']);"
```

**Tune PHP-FPM for your hardware** — edit `config/php-fpm.conf`:
- 16GB RAM → `pm.max_children = 150`
- 8GB RAM → `pm.max_children = 80`
- 4GB RAM → `pm.max_children = 40`

Then: `docker compose restart nextcloud`

---

## Optional: Encrypted Backups (Restic)

Uncomment the `nextcloud-backup` block in `docker-compose.yml` to enable daily encrypted,
deduplicated backups using [restic](https://restic.net/).

Minimum `.env` additions:

```env
BACKUP_PASSWORD=a-strong-passphrase       # encrypts all backups — do not lose this
BACKUP_REPOSITORY=/backups/nextcloud      # or switch to s3/b2/sftp without touching compose
BACKUP_LOCAL_PATH=/mnt/user/backups/nextcloud
```

Backs up `nextcloud_data` (user files) and `html` (app + installed apps) daily at 3am.
Retention: 7 daily, 4 weekly, 3 monthly snapshots.

**Switch to remote storage** — update `BACKUP_REPOSITORY` only:
- `s3:s3.amazonaws.com/bucket` — AWS S3
- `b2:bucket-name` — Backblaze B2
- `sftp:user@host:/path` — SFTP

**Database backup** — the backup service covers files only. For full disaster recovery,
add a nightly pg_dump on the host:

```bash
docker exec nextcloud-db pg_dump -U nextcloud nextcloud | gzip \
  > /mnt/user/backups/nextcloud-db-$(date +%Y%m%d).sql.gz
```

**Restore:**

```bash
docker exec nextcloud-backup restic snapshots
docker exec nextcloud-backup restic restore latest --target /restore
```

---

## File Reference

| File | Purpose |
|---|---|
| `docker-compose.yml` | Full stack definition |
| `Caddyfile` | Internal Caddy PHP-FPM proxy config |
| `.env.example` | Environment variable template |
| `UNRAID.md` | Unraid bind-mount path reference |
| `config/postgres.conf` | PostgreSQL 17 performance tuning |
| `config/php-fpm.conf` | PHP-FPM pool settings (pm.max_children etc.) |
| `config/php-opcache.ini` | OPcache + JIT tracing mode 1255 |
