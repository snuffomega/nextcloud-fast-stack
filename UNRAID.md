# Unraid Setup — Nextcloud Fast Stack 2026

By default all data is stored in `./data/` relative to `docker-compose.yml`.
On Unraid you likely want data under `/mnt/user/appdata/` instead.

There are two ways to do this:

---

## Option A — Symlink (easiest, no compose edits)

```bash
mkdir -p /mnt/user/appdata/nextcloud
ln -s /mnt/user/appdata/nextcloud /path/to/nextcloud-fast-stack/fpm/data
```

Docker sees `./data/` and writes to `/mnt/user/appdata/nextcloud/` transparently.

---

## Option B — Edit docker-compose.yml directly

Replace every `./data/` prefix with `/mnt/user/appdata/nextcloud/`:

| Default path | Unraid path |
|---|---|
| `./data/html` | `/mnt/user/appdata/nextcloud/html` |
| `./data/userdata` | `/mnt/user/appdata/nextcloud/userdata` |
| `./data/postgres` | `/mnt/user/appdata/nextcloud/postgres` |
| `./data/redis` | `/mnt/user/appdata/nextcloud/redis` |
| `./data/caddy/data` | `/mnt/user/appdata/nextcloud/caddy/data` |
| `./data/caddy/config` | `/mnt/user/appdata/nextcloud/caddy/config` |

Create the directories first:

```bash
mkdir -p /mnt/user/appdata/nextcloud/{html,userdata,postgres,redis,caddy/data,caddy/config}
```

Then `docker compose up -d` as normal.

---

## Post-install

```bash
docker exec -u www-data nextcloud php occ db:add-missing-indices
docker exec -u www-data nextcloud php occ db:convert-filecache-bigint
```
