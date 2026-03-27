#!/bin/sh
set -eu

if [ "${AUTO_INIT:-true}" != "true" ]; then
  echo "AUTO_INIT is disabled; exiting."
  exit 0
fi

# Helpers -----------------------------------------------------------
run_occ() {
  su -s /bin/sh www-data -c "php /var/www/html/occ $@"
}

next_trusted_domain_index() {
  su -s /bin/sh www-data -c "php -r 'require \"/var/www/html/config/config.php\"; global \$CONFIG; \$td = isset(\$CONFIG[\"trusted_domains\"]) ? \$CONFIG[\"trusted_domains\"] : []; echo count(\$td);'"
}

add_trusted_domain() {
  host=$1
  label=$2
  if [ -z "$host" ]; then
    return 0
  fi

  if run_occ config:system:get trusted_domains >/tmp/occ_trusted 2>&1; then
    if grep -F "${host}" /tmp/occ_trusted >/dev/null 2>&1; then
      echo "Trusted domain ${host} already present, skipping."
      return 0
    fi
  fi

  index=$(next_trusted_domain_index)
  if [ -z "$index" ]; then
    index=0
  fi

  echo "Adding trusted domain ${host} at index ${index}."
  run_occ config:system:set trusted_domains "${index}" --value="${host}" >/tmp/occ_trusted 2>&1 || true
}

# Wait until Nextcloud reports installed via occ status.
tries=0
max=120
while [ "$tries" -lt "$max" ]; do
  if su -s /bin/sh www-data -c 'php /var/www/html/occ status' >/tmp/occ_status 2>&1; then
    if grep -qi "installed" /tmp/occ_status || grep -q '"installed": true' /tmp/occ_status; then
      break
    fi
  fi
  tries=$((tries+1))
  echo "Waiting for Nextcloud to report installed ($tries/$max)"
  sleep 5
done

if [ "$tries" -ge "$max" ]; then
  echo "Timeout waiting for Nextcloud to finish installation."
  exit 1
fi

# Run recommended occ maintenance/fix commands (safe to re-run).
echo "Running occ post-install tasks..."

# Configure trusted domains before other maintenance commands.
add_trusted_domain "${NEXTCLOUD_EXTERNAL_HOST:-}" "external"
add_trusted_domain "${NEXTCLOUD_LOCAL_HOST:-}" "local"

su -s /bin/sh www-data -c "php /var/www/html/occ db:add-missing-indices" || true
su -s /bin/sh www-data -c "php /var/www/html/occ maintenance:repair --include-expensive" || true
su -s /bin/sh www-data -c "php /var/www/html/occ config:system:set default_phone_region --value='${DEFAULT_PHONE_REGION:-US}'" || true
su -s /bin/sh www-data -c "php /var/www/html/occ config:system:set maintenance_window_start --value='${MAINTENANCE_WINDOW_START:-2}'" || true

if [ -n "${OVERWRITEPROTOCOL:-}" ]; then
  echo "Setting overwriteprotocol=${OVERWRITEPROTOCOL}"
  su -s /bin/sh www-data -c "php /var/www/html/occ config:system:set overwriteprotocol --value='${OVERWRITEPROTOCOL}'" || true
fi

echo "Post-install tasks complete. Exiting."
exit 0
