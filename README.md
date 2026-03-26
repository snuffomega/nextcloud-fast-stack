# Nextcloud Fast Stack — Primary Install

[![Nextcloud](https://img.shields.io/badge/Nextcloud-33-0082C9?logo=nextcloud&logoColor=white)](https://hub.docker.com/_/nextcloud)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-17-4169E1?logo=postgresql&logoColor=white)](https://hub.docker.com/_/postgres)
[![Redis](https://img.shields.io/badge/Redis-7-DC382D?logo=redis&logoColor=white)](https://hub.docker.com/_/redis)
[![Caddy](https://img.shields.io/badge/Caddy-2-00ADD8?logo=caddy&logoColor=white)](https://hub.docker.com/_/caddy)

This repository provides a single primary install flow that works with an
external TLS tunnel (Cloudflare/Tailscale) forwarding to the stack, and also
supports running local TLS from Caddy. A short local HTTP-only reference is
available at docs/LOCAL-HTTP.md.

---

## Container Stack

```
docker-compose.yml
         |───────  core containers  ──────────────────────────────
         ├─ nextcloud               nextcloud:33-fpm-alpine
         ├─ nextcloud-caddy         caddy:2-alpine
         ├─ nextcloud-db            postgres:17-alpine
         ├─ nextcloud-redis         redis:7-alpine
         ├─ nextcloud-cron          nextcloud:33-fpm-alpine
         └─ nextcloud-init          nextcloud:33-fpm-alpine
                |
                v
         |───────  optional: uncommit in compose  ────────────────
         ├─ imaginary               nextcloud/aio-imaginary:latest
         └─ nextcloud-backup        mazzolino/restic:1
```




Quick checklist
- Copy `.env.example` → `.env` and set secrets.
- Choose the hostnames you will use and set `NEXTCLOUD_DOMAIN`, `NEXTCLOUD_EXTERNAL_HOST`, and `NEXTCLOUD_LOCAL_HOST` as appropriate.
- Keep `AUTO_INIT=true` to run the helper automatically (recommended).
- Start the stack with `docker compose up -d` and monitor `nextcloud-init`.

## Host configuration

- Set `NEXTCLOUD_DOMAIN` to the hostname your external tunnel will expose (for example `cloud.example.com`).
- Set `NEXTCLOUD_EXTERNAL_HOST` if that tunnel publishes a different hostname; Compose will include it in `NEXTCLOUD_TRUSTED_DOMAINS` automatically.
- If you also expose the stack locally via TLS, set `NEXTCLOUD_LOCAL_HOST` to that certificate hostname (for example `nextcloud.local`), or leave it blank to skip the local alias.
- Keep `OVERWRITEPROTOCOL=https` when the stack is reached over TLS (either from the tunnel or from Caddy), and leave it empty when you only run HTTP.

Quick Start

```bash
git clone https://github.com/snuffomega/nextcloud-fast-stack.git
cd nextcloud-fast-stack
cp .env.example .env
# Edit .env: set POSTGRES_PASSWORD, NEXTCLOUD_ADMIN_PASSWORD, NEXTCLOUD_DOMAIN, NEXTCLOUD_EXTERNAL_HOST, NEXTCLOUD_LOCAL_HOST
docker compose up -d
docker compose logs -f nextcloud nextcloud-init
```

What to set in `.env`

```env
POSTGRES_PASSWORD=generate_strong_password
NEXTCLOUD_ADMIN_PASSWORD=generate_strong_password
NEXTCLOUD_DOMAIN=nextcloud.yourdomain.com            # primary tunnel or local TLS host
NEXTCLOUD_EXTERNAL_HOST=nextcloud.yourdomain.com     # tunnel endpoint you expose externally
NEXTCLOUD_LOCAL_HOST=nextcloud.local                 # optional local TLS alias (leave empty to skip)
AUTO_INIT=true                                       # runs one-time occ helper, set 'false' to run cmds manually below

```

- Notes
- By default the stack expects TLS to be terminated by an external tunnel
    (Cloudflare/Tailscale) which forwards traffic to the host port mapped to
    Caddy (`${CADDY_HTTP_PORT:-8080}` by default). If you prefer local TLS, publish
    `443:443` for the Caddy service and enable the TLS block in `Caddyfile`.
- Host port published for Caddy is configurable (for example `8443:443`).
- Setting `NEXTCLOUD_EXTERNAL_HOST` and `NEXTCLOUD_LOCAL_HOST` in `.env` before
    the initial install ensures both hostnames are trusted automatically.

What the helper does

- The `nextcloud-init` one-time helper waits for the initial web installer to
    finish, then runs safe, idempotent `occ` commands:
    - `db:add-missing-indices`
    - `maintenance:repair --include-expensive`
    - set `default_phone_region` and `maintenance_window_start`
    - set `overwriteprotocol` when `OVERWRITEPROTOCOL` is set in `.env`

Manual commands (if you disable automation AUTO_INIT in .env)

```bash
# Set HTTPS protocol
docker exec -u www-data nextcloud php occ config:system:set overwriteprotocol --value="https"

# Add missing DB indices
docker exec -u www-data nextcloud php occ db:add-missing-indices

# Repair/optimize mimetype handling
docker exec -u www-data nextcloud php occ maintenance:repair --include-expensive

# Default phone region
docker exec -u www-data nextcloud php occ config:system:set default_phone_region --value="US"

# Maintenance window
docker exec -u www-data nextcloud php occ config:system:set maintenance_window_start --value=2
```

Reference: local HTTP-only setup is in docs/LOCAL-HTTP.md.

Troubleshooting

- If containers are not healthy: `docker compose ps` and `docker logs <service>`.
- If DB connection fails: `docker exec nextcloud-db psql -U nextcloud -d nextcloud -c "SELECT 1"`.
- Cron and Redis checks are listed in the original Troubleshooting section.

Updating

```bash
docker compose pull
docker compose up -d
docker exec -u www-data nextcloud php occ upgrade
docker exec -u www-data nextcloud php occ maintenance:mode --off
```

---

If you want I will tidy the Troubleshooting section and add a short Tailscale
note, otherwise this primary flow is ready and local HTTP is documented in
`docs/LOCAL-HTTP.md`.

---

## Updating

```bash
docker compose pull
docker compose up -d
docker exec -u www-data nextcloud php occ upgrade
docker exec -u www-data nextcloud php occ maintenance:mode --off
```

---

## Optional Containers

### Enable Imaginary (Faster Preview Generation)

1. Uncomment `imaginary:` block in `docker-compose.yml`
2. `docker compose up -d`
3. Add to Nextcloud `config/config.php`:
```php
'enabledPreviewProviders' => ['OC\Preview\Imaginary'],
'preview_imaginary_url'   => 'http://imaginary:9000',
```

### Enable Backups (Encrypted via Restic)

1. Uncomment `nextcloud-backup:` block in `docker-compose.yml`
2. Set in `.env`:
```env
BACKUP_PASSWORD=strong-encryption-key
BACKUP_REPOSITORY=/backups/nextcloud  # or s3://..., b2://..., sftp://...
BACKUP_CRON=0 3 * * *                 # Daily at 3 AM
```
3. `docker compose up -d`

### Tune PHP-FPM

Edit `config/php-fpm.conf`, adjust `pm.max_children`:
- **16GB RAM** → `150`
- **8GB RAM** → `80`
- **4GB RAM** → `40`

Then: `docker compose restart nextcloud`

---

## Managing Trusted Domains

**Important:** `NEXTCLOUD_DOMAIN` in `.env` only applies at **first install**. After that, domains are saved in `config.php`.

**Add a new domain/IP:**
```bash
docker exec -u www-data nextcloud php occ config:system:set trusted_domains 1 --value="192.168.1.100"
docker exec -u www-data nextcloud php occ config:system:set trusted_domains 2 --value="my.domain.com"
docker exec -u www-data nextcloud php occ config:system:set trusted_domains 3 --value="nextcloud.local"
```

**View current domains:**
```bash
docker exec nextcloud cat /var/www/html/config/config.php | grep -A 10 "trusted_domains"
```

You can have both IPs and domains in the same instance. Increment the index number for each additional domain.







## Troubleshooting

**Containers not healthy?**
```bash
docker compose ps
docker logs nextcloud
```

**Database connection error?**
```bash
docker exec nextcloud-db psql -U nextcloud -d nextcloud -c "SELECT 1"
```

**Cron not running?**
```bash
docker logs nextcloud-cron
docker exec -u www-data nextcloud php occ background:cron
```

**Redis issues?**
```bash
docker exec nextcloud-redis redis-cli PING
```

**Can't access from another machine?**
See "Managing Trusted Domains" — add your IP to the trusted list.

---

## License

Licensed under the [MIT License](LICENSE). See Nextcloud's own licensing at [nextcloud.com](https://nextcloud.com).

---

**Built for homelabs. Runs anywhere Docker does.**
