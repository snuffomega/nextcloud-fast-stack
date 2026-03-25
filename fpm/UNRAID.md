# Unraid Setup — Nextcloud Fast Stack 2026

Unraid stores container data under `/mnt/user/appdata/` rather than named
Docker volumes. Use the volume overrides below when running the stack.

---

## 1. Create directories

```bash
mkdir -p /mnt/user/appdata/nextcloud/{html,data,postgres,redis,caddy/data,caddy/config}
```

## 2. Start with bind-mount overrides

```bash
docker compose -f docker-compose.yml up -d \
  --volume /mnt/user/appdata/nextcloud/html:/var/www/html \
  --volume /mnt/user/appdata/nextcloud/data:/var/www/html/data
```

Or simply edit the `volumes:` section in `docker-compose.yml` directly,
replacing named volumes with the paths below:

| Service | Named volume | Unraid path |
|---|---|---|
| `nextcloud` | `html:/var/www/html` | `/mnt/user/appdata/nextcloud/html:/var/www/html` |
| `nextcloud` | `nextcloud_data:/var/www/html/data` | `/mnt/user/appdata/nextcloud/data:/var/www/html/data` |
| `nextcloud-caddy` | `html:/var/www/html:ro` | `/mnt/user/appdata/nextcloud/html:/var/www/html:ro` |
| `nextcloud-caddy` | `caddy_data:/data` | `/mnt/user/appdata/nextcloud/caddy/data:/data` |
| `nextcloud-caddy` | `caddy_config:/config` | `/mnt/user/appdata/nextcloud/caddy/config:/config` |
| `nextcloud-db` | `nextcloud_db:/var/lib/postgresql/data` | `/mnt/user/appdata/nextcloud/postgres:/var/lib/postgresql/data` |
| `nextcloud-redis` | `nextcloud_redis:/data` | `/mnt/user/appdata/nextcloud/redis:/data` |

## 3. Post-install

Same as the main README — run the `occ` commands once Nextcloud is accessible:

```bash
docker exec -u www-data nextcloud php occ db:add-missing-indices
docker exec -u www-data nextcloud php occ db:convert-filecache-bigint
```
