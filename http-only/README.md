# Nextcloud FPM LEAN - Standard Install


[![Nextcloud](https://img.shields.io/badge/Nextcloud-33-0082C9?logo=nextcloud&logoColor=white)](https://hub.docker.com/_/nextcloud)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-17-4169E1?logo=postgresql&logoColor=white)](https://hub.docker.com/_/postgres)
[![Redis](https://img.shields.io/badge/Redis-7-DC382D?logo=redis&logoColor=white)](https://hub.docker.com/_/redis)
[![Caddy](https://img.shields.io/badge/Caddy-2-00ADD8?logo=caddy&logoColor=white)](https://hub.docker.com/_/caddy)

This Nextcloud FPM Lean Stack, customized to be a fast, filesharing-first Nextcloud stack that pairs the Official FPM server with Caddy for a purpose-built experience, avoiding unneeded bloat of the all-in-one image. This stack sticks to the official FPM build with Postgrs for a noticeably snappier experience with faster startup times and easily 3× faster under load, during uploads/downloads and cron-heavy workflows (over the AIO image). If you want a slightly more focused experience where performance is peramount this in designed for you. 


Couple this with your preferred tunnel (Cloudflare, Pangolin, Tailscale, etc) for HTTPS access.

## Container Stack

```
docker-compose.yml
         |───────  core containers  ─────────────────────────
         ├─ nextcloud               nextcloud:33-fpm-alpine
         ├─ nextcloud-caddy         caddy:2-alpine
         ├─ nextcloud-db            postgres:17-alpine
         ├─ nextcloud-redis         redis:7-alpine
         ├─ nextcloud-cron          nextcloud:33-fpm-alpine
         └─ nextcloud-init          nextcloud:33-fpm-alpine
                |
                v
         |───────  optional: uncommit in compose ─────
         ├─ imaginary               nextcloud/aio-imaginary:latest
         └─ nextcloud-backup        mazzolino/restic:1
```

## Quick Start
```bash
git clone https://github.com/snuffomega/nextcloud-fast-stack.git
cd nextcloud-fast-stack/http-only
cp .env.example .env
docker compose up -d
docker compose logs -f nextcloud nextcloud-init
```

1. Copy `.env.example` → `.env` and set the required secrets + the public hostname
   your tunnel will expose.
2. Run `docker compose up -d` from this directory.
3. Tail `docker compose logs -f nextcloud nextcloud-init` until the helper reports
   `Post-install tasks complete`.
4. Point your tunnel (Cloudflare Tunnel, Tailscale, etc.) at `localhost:${CADDY_HTTP_PORT:-8080}`
   so `https://your-tunnel-hostname` routes through the stack.

## `.env` at a glance

```env
POSTGRES_PASSWORD=strong-db-password
NEXTCLOUD_ADMIN_PASSWORD=strong-admin-password
CADDY_HTTP_PORT=8080                  # HTTP port published by Caddy
NEXTCLOUD_DOMAIN=cloud.example.com    # hostname your tunnel exposes
OVERWRITEPROTOCOL=https               # tunnels terminate TLS, so force HTTPS in Nextcloud
AUTO_INIT=true                        # run the helper automatically
``` 
- `NEXTCLOUD_DOMAIN` must match whatever hostname you use inside the tunnel
  configuration so Nextcloud knows which trusted domain to record.
- `OVERWRITEPROTOCOL=https` keeps generated URLs pointing to HTTPS even though
  Caddy itself serves HTTP inside the container.
- Leave `AUTO_INIT=true` so the helper runs the maintenance/repair `occ` commands
  automatically (see `bin/init-nextcloud.sh`).

## What this stack includes

- `nextcloud`, `nextcloud-cron`, `nextcloud-init`, `nextcloud-db`, and `nextcloud-redis`
  — the same containers as the main stack.
- `nextcloud-caddy` listens on HTTP (`:${CADDY_HTTP_PORT:-8080}`) and forwards PHP requests
  to `nextcloud:9000`.
- `nextcloud-init` runs the helper script once the web installer finishes.

## Caddy

`Caddyfile` in this folder is preconfigured for HTTP only; no TLS settings are defined
here because the tunnel handles encryption.

## Maintenance helper

`bin/init-nextcloud.sh` is the same helper used in the HTTPS stack. It waits for
`occ status` to report "installed", runs recommended maintenance commands, and
sets `overwriteprotocol` to the value of `OVERWRITEPROTOCOL`.

## Launching

```bash
cd http-only
docker compose up -d
``` 

Stop with `docker compose down` and bring the tunnel back up after any restarts.

## Advanced

- Want to change Caddy’s HTTP port? Override `CADDY_HTTP_PORT` in `.env`.
- Need email notifications or other extensions? Configure them inside Nextcloud and
  keep using this HTTP-only entry point; the external tunnel keeps all traffic
  encrypted once it leaves the host.

## Manual commands

Manual commands if you disable helper and set to 'false' in .env

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

## Updating

```bash
docker compose pull
docker compose up -d
docker exec -u www-data nextcloud php occ upgrade
docker exec -u www-data nextcloud php occ maintenance:mode --off
```


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


## License

Licensed under the [MIT License](LICENSE). See Nextcloud's own licensing at [nextcloud.com](https://nextcloud.com).

**Built for homelabs. Runs anywhere Docker does.**
