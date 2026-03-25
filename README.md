# Nextcloud Fast Stack — Homelab Edition

[![Nextcloud](https://img.shields.io/badge/Nextcloud-33-0082C9?logo=nextcloud&logoColor=white)](https://hub.docker.com/_/nextcloud)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-17-4169E1?logo=postgresql&logoColor=white)](https://hub.docker.com/_/postgres)
[![Redis](https://img.shields.io/badge/Redis-7-DC382D?logo=redis&logoColor=white)](https://hub.docker.com/_/redis)
[![Caddy](https://img.shields.io/badge/Caddy-2-00ADD8?logo=caddy&logoColor=white)](https://hub.docker.com/_/caddy)

**HTTP-only stack. All official images. No custom builds.**

Nextcloud 33 FPM · PostgreSQL 17 · Redis 7 · Caddy 2 · PHP JIT enabled · ~100–150ms TTFB

Simple Docker composition for homelab Nextcloud. All services run on internal Docker network. Caddy proxy handles HTTP requests on port 8080. You control external access (Tailscale, Cloudflare Tunnel, reverse proxy, etc.).

---

## Architecture

```
docker compose up -d
         |
         ├─ nextcloud      PHP-FPM 8.3 · PostgreSQL/Redis client
         ├─ nextcloud-cron Background jobs every 5 min
         ├─ nextcloud-db   PostgreSQL 17 database
         ├─ nextcloud-redis Redis 7 session/file lock cache (AOF persistent)
         └─ nextcloud-caddy HTTP proxy (port 8080)
                |
                v
    Access: http://localhost:8080
            http://<your-home-ip>:8080
```

All persistent data lives in `./data/` next to `docker-compose.yml`:
- `./data/html/` — Nextcloud app files
- `./data/userdata/` — User files and metadata
- `./data/postgres/` — PostgreSQL database
- `./data/redis/` — Redis AOF persistence

---

## Quick Start

**Prerequisites:** Docker Engine 24+ and Docker Compose v2

```bash
git clone https://github.com/snuffomega/nextcloud-fast-stack.git
cd nextcloud-fast-stack
cp .env.example .env
```

Edit `.env` and set:

```env
POSTGRES_PASSWORD=randomly_generate_a_strong_password
NEXTCLOUD_ADMIN_PASSWORD=another_strong_password
NEXTCLOUD_DOMAIN=localhost          # or 192.168.1.100, 10.0.0.50, etc.
```

Start the stack:

```bash
docker compose up -d
docker compose logs -f nextcloud
```

Wait for `nextcloud` container to report "healthy", then visit:
- **http://localhost:8080** (if running locally)
- **http://192.168.1.100:8080** (replace with your home IP)

Complete the Nextcloud setup wizard. Database is pre-populated; just create admin account.

---

## Updating

```bash
docker compose pull
docker compose up -d
docker exec -u www-data nextcloud php occ upgrade
docker exec -u www-data nextcloud php occ maintenance:mode --off
```

All images are official. `docker pull` automatically gets latest minor/patch version within the pinned major tag.

---

## Post-Install Recommendations

```bash
# Verify installation
docker exec -u www-data nextcloud php occ status

# Add missing DB indices (clears admin warning)
docker exec -u www-data nextcloud php occ db:add-missing-indices

# Convert file cache to bigint for future growth
docker exec -u www-data nextcloud php occ db:convert-filecache-bigint
```

Check **Admin → Basic settings** — "Last cron executed" should show within 10 minutes of deploy.

---

## External Access (HTTPS)

This stack is HTTP-only on port 8080. For external HTTPS access, use one of these:

### Option A: Tailscale
```bash
# On your home server
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```
Then access from anywhere as: `http://<tailscale-hostname>:8080`

### Option B: Cloudflare Tunnel
```bash
docker run -it --rm cloudflare/cloudflared:latest login
docker run -d cloudflare/cloudflared:latest tunnel run
```
Then tunnel name → local port 8080 → DNS CNAME to your domain.

### Option C: Your Own Reverse Proxy
- **Traefik**: Point entrypoint to `http://localhost:8080`
- **Caddy**: Similar to above
- **Nginx**: http upstream to Caddy service

---

## Optional Features

**Enable Imaginary** (faster thumbnail generation)
1. Uncomment `imaginary:` block in `docker-compose.yml`
2. Restart: `docker compose up -d`
3. Add to Nextcloud `config/config.php`:
```php
'enabledPreviewProviders' => ['OC\Preview\Imaginary'],
'preview_imaginary_url'   => 'http://imaginary:9000',
```

**Enable Backups** (encrypted incremental via Restic)
1. Uncomment `nextcloud-backup:` block in `docker-compose.yml`
2. Set in `.env`:
```env
BACKUP_PASSWORD=strong-encryption-key
BACKUP_REPOSITORY=/backups/nextcloud       # local
# or: s3://..., b2://..., sftp://...
BACKUP_CRON=0 3 * * *                      # daily 3am
```
3. Restart: `docker compose up -d`
4. Test: `docker exec nextcloud-backup restic snapshots`

**Tune PHP-FPM** (`config/php-fpm.conf`)
- 16GB RAM → `pm.max_children = 150`
- 8GB RAM → `pm.max_children = 80`
- 4GB RAM → `pm.max_children = 40`

**Check JIT is enabled:**
```bash
docker exec nextcloud php -r "var_dump(opcache_get_status()['jit']);"
```

---

## Troubleshooting

**Container unhealthy?**
```bash
docker compose ps
docker logs nextcloud
```

**Database won't connect?**
```bash
docker exec nextcloud-db psql -U nextcloud -d nextcloud -c "SELECT 1"
```

**Cron not running?**
```bash
docker logs nextcloud-cron
docker exec -u www-data nextcloud php occ background:cron
```

**Redis connection issues?**
```bash
docker exec nextcloud-redis redis-cli PING
```

---

## License

Licensed under the [MIT License](LICENSE). See Nextcloud's own licensing at [nextcloud.com](https://nextcloud.com).

---

**Built for homelabs. Runs anywhere Docker does.**
