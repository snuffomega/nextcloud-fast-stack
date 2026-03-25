# FrankenPHP — Nextcloud Fast Stack 2026
# Extends dunglas/frankenphp with all PHP extensions required by Nextcloud.
# Build context is the repo ROOT (set in docker-compose.yml):
#   build:
#     context: ..
#     dockerfile: frankenphp/Dockerfile

FROM dunglas/frankenphp:1-php8.3-alpine

# ── System dependencies ───────────────────────────────────
RUN apk add --no-cache \
    # Image processing
    imagemagick-dev \
    libheif-dev \
    # Archive
    libzip-dev \
    bzip2-dev \
    # Database
    postgresql-dev \
    # Internationalisation
    icu-dev \
    # XML / WebDAV
    libxml2-dev \
    # Image formats
    freetype-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    libwebp-dev \
    # Math
    gmp-dev \
    # LDAP (optional — comment out if not needed)
    openldap-dev

# ── PHP extensions ────────────────────────────────────────
# install-php-extensions handles compilation and dependency
# resolution for each extension automatically.
ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions \
    /usr/local/bin/install-php-extensions
RUN chmod +x /usr/local/bin/install-php-extensions && \
    install-php-extensions \
        bcmath \
        bz2 \
        exif \
        gd \
        gmp \
        imagick \
        intl \
        ldap \
        opcache \
        pcntl \
        pdo_pgsql \
        redis \
        sysvsem \
        zip

# ── PHP configuration ─────────────────────────────────────
# Use production defaults as the base
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# OPcache + JIT (shared config from repo root)
COPY config/php-opcache.ini /usr/local/etc/php/conf.d/opcache.ini

# ── Caddyfile ─────────────────────────────────────────────
COPY Caddyfile /etc/caddy/Caddyfile

WORKDIR /var/www/html
