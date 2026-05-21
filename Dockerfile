# Use the latest stable Debian as the base image
FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install runtime packages, configure Sury, install PHP, then purge transient
# build-only packages (curl/gnupg/lsb-release) in the same layer so they
# don't ship in the final image.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        apache2 \
        ca-certificates \
        tini; \
    savedAptMark="$(apt-mark showmanual)"; \
    apt-get install -y --no-install-recommends \
        curl \
        gnupg \
        lsb-release; \
    curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg; \
    echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" \
        > /etc/apt/sources.list.d/php.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        php8.5-fpm \
        php8.5-mysql \
        php8.5-gd \
        php8.5-curl \
        php8.5-mbstring \
        php8.5-xml \
        php8.5-zip \
        php8.5-intl \
        php8.5-soap \
        php8.5-imagick \
        php8.5-bcmath; \
    apt-mark auto curl gnupg lsb-release > /dev/null; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    apt-mark manual $savedAptMark > /dev/null; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# Custom configuration files
COPY custom-php.ini /etc/php/8.5/fpm/conf.d/99-custom.ini
COPY apache-vhost.conf /etc/apache2/sites-available/000-default.conf

# Apache modules (headers added for the security-header directives in the vhost).
RUN a2enmod rewrite proxy_fcgi setenvif remoteip headers

# Harden Apache banner.
RUN sed -i 's/^ServerTokens .*/ServerTokens Prod/' /etc/apache2/conf-available/security.conf && \
    sed -i 's/^ServerSignature .*/ServerSignature Off/' /etc/apache2/conf-available/security.conf

# Send logs to Docker's stdout/stderr.
RUN ln -sf /dev/stdout /var/log/apache2/access.log && \
    ln -sf /dev/stderr /var/log/apache2/error.log

WORKDIR /var/www/html

EXPOSE 80

# tini reaps zombies and (-g) forwards SIGTERM to the whole process group,
# so both Apache and PHP-FPM shut down cleanly on `docker stop`.
ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["sh", "-c", "php-fpm8.5 --nodaemonize & apache2ctl -D FOREGROUND"]
