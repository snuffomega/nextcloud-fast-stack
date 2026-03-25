# Nextcloud Fast Stack — FrankenPHP

[![FrankenPHP](https://img.shields.io/badge/FrankenPHP-1-7C3AED?logo=php&logoColor=white)](https://frankenphp.dev)
[![PHP](https://img.shields.io/badge/PHP-8.3-777BB4?logo=php&logoColor=white)](https://www.php.net)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-17-4169E1?logo=postgresql&logoColor=white)](https://hub.docker.com/_/postgres)
[![Redis](https://img.shields.io/badge/Redis-7-DC382D?logo=redis&logoColor=white)](https://hub.docker.com/_/redis)

**EXPERIMENTAL — Nextcloud on FrankenPHP is not yet officially documented.**

FrankenPHP 1 · PHP 8.3 · PostgreSQL 17 · Redis 7 · JIT enabled · ~50–70ms TTFB

Replaces the `nextcloud` + `nextcloud-caddy` two-container pair with a **single
FrankenPHP container** — PHP runs in-process inside Caddy, eliminating the
FastCGI socket hop on every request.

> Using official images and want simpler updates? Use the PHP-FPM stack instead:
> [`../fpm/`](../fpm/README.md).

---

## How it works

```
docker compose up -d --build
         |
         v
  nextcloud-init  → copies app files + runs occ install → exits
         |
         v
  nextcloud_net (Docker bridge, internal)
  ├── nextcloud-frankenphp  PHP + Caddy in-process on :CADDY_PORT (default 8080)
  ├── nextcloud-cron        Background job runner (every 5 min)
  ├── nextcloud-db          PostgreSQL 17
  └── nextcloud-redis       Redis 7
         |
         v
  Point your reverse proxy at nextcloud-frankenphp:8080
```

---

## Quick Start

**Prerequisites:** Docker Engine 24+ and Docker Compose v2

```bash
git clone https://github.com/snuffomega/nextcloud-fast-stack.git
cd nextcloud-fast-stack/frankenphp
cp .env.example .env
```

Edit `.env` — at minimum set:

```env
POSTGRES_PASSWORD=a-strong-db-password
NEXTCLOUD_ADMIN_PASSWORD=a-strong-admin-password
NEXTCLOUD_DOMAIN=cloud.yourdomain.com     # or LAN IP: 192.168.1.100
```

```bash
docker compose up -d --build
docker compose logs -f nextcloud
```

First run is slower — Docker builds the image, then `nextcloud-init` installs
Nextcloud into the shared volume. Subsequent starts are fast (init exits immediately).

**Port conflict?** Change `CADDY_PORT` in `.env`.

---

## Worker Mode (~40% additional throughput)

Worker mode keeps PHP alive between requests — Nextcloud's bootstrap (autoloading,
config, DI container) is loaded once and stays in memory permanently.

Uncomment the `frankenphp { worker ... }` block in `Caddyfile`:

```caddy
frankenphp {
    worker /var/www/html/index.php
}
```

Then rebuild and restart:

```bash
docker compose up -d --build
```

> Test in staging first. Worker mode is improving with each Nextcloud release
> but is not yet the default recommendation.

---

## Updating

FrankenPHP requires a rebuild when either Nextcloud or FrankenPHP/PHP versions change.

**Nextcloud minor/patch update** (e.g. 33.0.1 → 33.0.2):

```bash
# Pull the new init image
docker compose pull nextcloud-init
# Rebuild FrankenPHP image and re-run init
docker compose up -d --build
docker exec -u www-data nextcloud-frankenphp php occ upgrade
docker exec -u www-data nextcloud-frankenphp php occ maintenance:mode --off
```

**FrankenPHP or PHP version bump** — edit the `FROM` line in `Dockerfile`:

```dockerfile
FROM dunglas/frankenphp:1-php8.3-alpine   # change tag here
```

Then rebuild: `docker compose up -d --build`

---

## Essential Post-Install

Run once after Nextcloud is accessible:

```bash
docker exec -u www-data nextcloud-frankenphp php occ db:add-missing-indices
docker exec -u www-data nextcloud-frankenphp php occ db:convert-filecache-bigint
docker exec -u www-data nextcloud-frankenphp php occ status
```

---

## Background Jobs (Cron)

The `nextcloud-cron` service is required for activity feeds, notifications, share
expiry, and all app-level background tasks.

```bash
docker exec -u www-data nextcloud-frankenphp php occ background:cron
docker logs nextcloud-cron
```

---

## Optional: Encrypted Backups (Restic)

Same as the FPM stack — uncomment the `nextcloud-backup` block in `docker-compose.yml`.

Minimum `.env` additions:

```env
BACKUP_PASSWORD=a-strong-passphrase
BACKUP_REPOSITORY=/backups/nextcloud
BACKUP_LOCAL_PATH=/mnt/user/backups/nextcloud
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
| `Dockerfile` | FrankenPHP image build (extends `dunglas/frankenphp`) |
| `Caddyfile` | Embedded Caddy config (worker mode toggle here) |
| `.env.example` | Environment variable template |
| `config/postgres.conf` | PostgreSQL 17 performance tuning |
| `config/php-opcache.ini` | OPcache + JIT (baked into image at build time) |
