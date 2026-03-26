Local HTTP-only Reference

This short reference explains how to run the stack in a private network
without TLS (HTTP only).

When to use
- Small, private networks behind a VPN/router where HTTPS is not required.

Steps
1. In `.env` set `NEXTCLOUD_DOMAIN` to the host or IP you will use (example: `192.168.1.111`), and set `CADDY_HTTP_PORT` if you want a different port (default 8080).
2. Keep `docker-compose.yml` Caddy mapping on `${CADDY_HTTP_PORT:-8080}:8080` so Caddy serves HTTP.
3. Do NOT publish port 443 for Caddy (leave TLS block commented in `Caddyfile`).
4. Start the stack:

```bash
docker compose up -d
```

5. If you used `AUTO_INIT=true`, the helper will run DB/index/repair tasks. If you prefer to run everything manually, set `AUTO_INIT=false` and run the commands below after the web-based installer finishes:

```bash
# Clear protocol override (ensure HTTP links)
docker exec -u www-data nextcloud php occ config:system:set overwriteprotocol --value=""

# Add missing indices
docker exec -u www-data nextcloud php occ db:add-missing-indices

# Repair/optimize mimetype handling
docker exec -u www-data nextcloud php occ maintenance:repair --include-expensive

# Default phone region
docker exec -u www-data nextcloud php occ config:system:set default_phone_region --value="US"

# Maintenance window (example: 2 AM)
docker exec -u www-data nextcloud php occ config:system:set maintenance_window_start --value=2
```

Notes
- Browsers will show "insecure" for HTTP links. Keep this mode inside a secure network.
- To move to local TLS later, update `docker-compose.yml` to publish `443:443`, enable the TLS block in `Caddyfile`, set `NEXTCLOUD_DOMAIN` to the TLS hostname, and set `OVERWRITEPROTOCOL=https` (or let `nextcloud-init` set it).
