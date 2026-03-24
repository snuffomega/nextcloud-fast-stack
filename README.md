# Nextcloud Fast Stack 2026

A high-performance, self-hosted Nextcloud stack.
PHP-FPM 8.3 · PostgreSQL 17 · Redis 7 · Caddy 2 · JIT enabled

Nextcloud runs **fully internally** on a Docker network — no ports exposed to
the host, no TLS config to wrestle with. How you connect to it from outside
your network is entirely up to you.

---

## How it works

```
docker compose up -d
         |
         v
  nextcloud_net (Docker bridge, internal)
  ├── nextcloud       PHP-FPM on :9000
  ├── nextcloud-caddy PHP proxy on :CADDY_PORT (default 8080)
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
cd nextcloud-fast-stack
cp .env.example .env
```

Edit `.env` — set `POSTGRES_PASSWORD` and `NEXTCLOUD_ADMIN_PASSWORD` at minimum.

```bash
docker compose up -d
docker compose logs -f nextcloud-caddy
```

Nextcloud is now accessible on your Docker network at `http://nextcloud-caddy:8080`.
Point your reverse proxy of choice there.

**Port conflict?** If another container already uses 8080, change `CADDY_PORT` in `.env`.

---

## Unraid

See [UNRAID.md](UNRAID.md) for the full volume path reference.

Short version: create `/mnt/user/appdata/nextcloud/` subdirectories, then
replace the named volumes in `docker-compose.yml` with the corresponding
bind-mount paths from that file.

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

## FrankenPHP (Experimental ~50ms TTFB)

Collapses Caddy + PHP-FPM into a single container using FrankenPHP's in-process
PHP engine. Same internal model — no ports, no TLS, same relay handoff.

> FrankenPHP v1.x is production-ready. Nextcloud on FrankenPHP is not yet
> officially documented. Test in staging before production use.

```bash
cd frankenphp
docker compose up -d --build
```

First run is slower (Docker build + DB init). Subsequent starts are fast.\
Enable worker mode in `frankenphp/Caddyfile` after confirming basic operation.

---

## File Reference

| File | Purpose |
|---|---|
| `docker-compose.yml` | Main stack |
| `UNRAID.md` | Unraid bind-mount path reference |
| `.env.example` | Environment variable template |
| `Caddyfile` | Internal Caddy proxy config |
| `config/postgres.conf` | PostgreSQL 17 performance tuning |
| `config/php-fpm.conf` | PHP-FPM pool (pm.max_children etc.) |
| `config/php-opcache.ini` | OPcache + JIT tracing mode 1255 |
| `frankenphp/` | Experimental FrankenPHP variant |
