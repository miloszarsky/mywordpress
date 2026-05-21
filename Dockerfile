# Use the latest stable Debian as the base image
FROM debian:trixie-slim

# Set environment variables for non-interactive install
ENV DEBIAN_FRONTEND=noninteractive

# 1. System updates and installation of necessary packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    apache2 \
    ca-certificates \
    curl \
    gnupg \
    wget \
    unzip \
    lsb-release && \
    # ^^^ THE FIX IS HERE ^^^
    # 2. Add Sury PPA for the latest PHP versions
    curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list && \
    apt-get update && \
    # 3. Install PHP 8.5 and required WordPress modules
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
    php8.5-bcmath && \
    # 4. Clean up apt cache
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 5. Copy custom configuration files
COPY custom-php.ini /etc/php/8.5/fpm/conf.d/99-custom.ini
COPY apache-vhost.conf /etc/apache2/sites-available/000-default.conf

# 6. Configure Apache
RUN a2enmod rewrite proxy_fcgi setenvif remoteip

# 6b. Harden Apache Security (Anonymize Banner)
RUN sed -i 's/^ServerTokens .*/ServerTokens Prod/' /etc/apache2/conf-available/security.conf && \
    sed -i 's/^ServerSignature .*/ServerSignature Off/' /etc/apache2/conf-available/security.conf

# 7. Redirect Apache logs to Docker's stdout and stderr streams
RUN ln -sf /dev/stdout /var/log/apache2/access.log && \
    ln -sf /dev/stderr /var/log/apache2/error.log

# 8. Set the working directory (your WordPress files will be mounted here)
WORKDIR /var/www/html

# Expose port 80 for the web server
EXPOSE 80

# The command to run when the container starts.
# It starts PHP-FPM in the background and Apache in the foreground.
CMD ["sh", "-c", "php-fpm8.5 & apache2ctl -D FOREGROUND"]
