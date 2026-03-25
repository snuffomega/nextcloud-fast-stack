# Nextcloud Fast Stack

[![Nextcloud](https://img.shields.io/badge/Nextcloud-33-0082C9?logo=nextcloud&logoColor=white)](https://hub.docker.com/_/nextcloud)
[![FrankenPHP](https://img.shields.io/badge/FrankenPHP-1-7C3AED?logo=php&logoColor=white)](https://frankenphp.dev)
[![License](https://img.shields.io/github/license/snuffomega/nextcloud-fast-stack)](LICENSE)

A high-performance, self-hosted Nextcloud stack in two flavours.

Nextcloud runs **fully internally** on a Docker network — no ports exposed to the host,
no TLS to configure. Point your reverse proxy (Traefik, Caddy, Nginx, Tailscale,
Cloudflare Tunnel) at the internal HTTP port and call it done.

---

## Choose your stack

| | [📁 fpm/](fpm/README.md) | [📁 frankenphp/](frankenphp/README.md) |
|---|---|---|
| **Images** | Official only — no build | Custom build on `dunglas/frankenphp` |
| **PHP runtime** | PHP-FPM (pooled workers) | In-process via FrankenPHP |
| **Updating** | `docker compose pull` | Rebuild image |
| **Nextcloud support** | Fully official | Not yet officially documented |
| **Recommended for** | Production, simplicity | Performance testing, experimenters |

---

## Performance at a glance

| Stack | TTFB | Memory (idle) | Containers | PHP bootstrap |
|---|---|---|---|---|
| Nextcloud AIO | ~200–400ms | ~1.5–2 GB | 8–12 | Per request |
| **fpm/** (this repo) | ~100–150ms | ~500 MB | 5 | Per request |
| **frankenphp/** | ~50–70ms | ~400 MB | 4 | Per request |
| **frankenphp/** + worker mode | ~30–50ms | ~450 MB | 4 | **Once on startup** |

Worker mode (uncommented in `frankenphp/Caddyfile`) keeps Nextcloud's entire PHP
bootstrap loaded in memory — eliminating per-request autoloading, config parsing,
and DI container rebuild.

---

## Quick start

**PHP-FPM (recommended):**
```bash
cd fpm
cp .env.example .env   # fill in passwords + NEXTCLOUD_DOMAIN
docker compose up -d
```

**FrankenPHP (experimental):**
```bash
cd frankenphp
cp .env.example .env   # fill in passwords + NEXTCLOUD_DOMAIN
docker compose up -d --build
```

Both stacks expose Nextcloud internally on `http://<container>:8080` (default).
No ports are published to the host — wire it to your existing reverse proxy.

---

## Repo layout

```
fpm/                  PHP-FPM stack (PHP-FPM · Caddy · PostgreSQL · Redis)
├── docker-compose.yml
├── Caddyfile
├── .env.example
├── UNRAID.md
└── config/           postgres.conf · php-fpm.conf · php-opcache.ini

frankenphp/           FrankenPHP stack (FrankenPHP · PostgreSQL · Redis)
├── docker-compose.yml
├── Dockerfile
├── Caddyfile
├── .env.example
└── config/           postgres.conf · php-opcache.ini
```

Both stacks are fully independent — run one, not both.

---

## Shared design principles

- **No host port exposure** — internal Docker network only; your reverse proxy is the entry point
- **PostgreSQL 17** — not MariaDB; better query planner, native JSON, superior concurrency
- **Redis 7 with AOF persistence** — session cache + distributed file locking, survives restarts
- **JIT enabled** (tracing mode 1255) — ~10–15% throughput gain on PHP 8.3
- **Cron container** — background jobs run every 5 min; required for notifications, share expiry, indexing
- **Optional Restic backup** — encrypted, deduplicated; uncomment one block in docker-compose.yml
