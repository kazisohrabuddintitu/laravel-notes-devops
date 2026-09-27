# syntax=docker/dockerfile:1

# ------------------------------------------------------------------
# Base: PHP 8.5 with PHP-FPM + nginx (Debian Trixie), runs as www-data
# ------------------------------------------------------------------
FROM serversideup/php:8.5-fpm-nginx-trixie AS base

USER root
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
RUN install-php-extensions pdo_pgsql
USER www-data

WORKDIR /var/www/html

# ------------------------------------------------------------------
# Stage 1: PHP dependencies (production only, no dev packages)
# ------------------------------------------------------------------
FROM base AS vendor

COPY --chown=www-data:www-data composer.json composer.lock ./
RUN composer install --no-dev --no-interaction --prefer-dist --no-scripts --no-autoloader

COPY --chown=www-data:www-data . .
RUN composer dump-autoload --no-dev --optimize

# ------------------------------------------------------------------
# Stage 2: Frontend assets (Vite needs Node, Wayfinder needs PHP)
# ------------------------------------------------------------------
FROM base AS assets

USER root
COPY --from=node:22-trixie-slim /usr/local/bin/node /usr/local/bin/node
COPY --from=node:22-trixie-slim /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm

COPY package.json package-lock.json .npmrc ./
RUN npm ci

COPY --from=vendor /var/www/html ./
RUN npm run build

# ------------------------------------------------------------------
# Stage 3: Final production image
# ------------------------------------------------------------------
FROM base AS production

ENV PHP_OPCACHE_ENABLE=1

COPY --from=vendor --chown=www-data:www-data /var/www/html ./
COPY --from=assets --chown=www-data:www-data /var/www/html/public/build ./public/build
