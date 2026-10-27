FROM debian:bookworm-slim

LABEL maintainer="mgboydev" \
      description="Reusable Laravel-ready PHP 8.3 base image with Nginx, OCI8, Redis and Memcached"

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Jakarta \
    PHP_VERSION=8.3 \
    ORACLE_HOME=/usr/local/instantclient \
    TNS_ADMIN=/usr/local/instantclient/network/admin \
    LD_LIBRARY_PATH=/usr/local/instantclient \
    PATH="/usr/local/instantclient:${PATH}" \
    COMPOSER_ALLOW_SUPERUSER=1

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ------------------------------------------------------------
# 1. Install repository keys and runtime packages
# ------------------------------------------------------------
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        tzdata; \
    install -d -m 0755 /etc/apt/keyrings; \
    curl -fsSL https://packages.sury.org/php/apt.gpg \
        | gpg --dearmor -o /etc/apt/keyrings/sury-php.gpg; \
    curl -fsSL https://nginx.org/keys/nginx_signing.key \
        | gpg --dearmor -o /etc/apt/keyrings/nginx.gpg; \
    echo "deb [signed-by=/etc/apt/keyrings/sury-php.gpg] https://packages.sury.org/php/ bookworm main" \
        > /etc/apt/sources.list.d/sury-php.list; \
    echo "deb [signed-by=/etc/apt/keyrings/nginx.gpg] https://nginx.org/packages/debian bookworm nginx" \
        > /etc/apt/sources.list.d/nginx.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        nginx=1.30.6-1~bookworm \
        supervisor \
        git \
        nano \
        wget \
        zip \
        unzip \
        ghostscript \
        libaio1 \
        libnsl2 \
        php8.3-cli \
        php8.3-common \
        php8.3-fpm \
        php8.3-bcmath \
        php8.3-curl \
        php8.3-gd \
        php8.3-gmp \
        php8.3-igbinary \
        php8.3-imagick \
        php8.3-intl \
        php8.3-mbstring \
        php8.3-memcached \
        php8.3-msgpack \
        php8.3-mysql \
        php8.3-opcache \
        php8.3-pgsql \
        php8.3-readline \
        php8.3-redis \
        php8.3-xml \
        php8.3-zip; \
    ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime; \
    echo "${TZ}" > /etc/timezone; \
    rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# 2. Install Oracle Instant Client 19.26 and compile OCI8
# ------------------------------------------------------------
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        autoconf \
        gcc \
        make \
        pkg-config \
        libc6-dev \
        zlib1g-dev \
        php8.3-dev; \
    mkdir -p /tmp/oracle/basic /tmp/oracle/sdk /usr/local/instantclient_19_26; \
    curl -fL --retry 3 \
        https://download.oracle.com/otn_software/linux/instantclient/1926000/instantclient-basic-linux.x64-19.26.0.0.0dbru.zip \
        -o /tmp/oracle/instantclient-basic.zip; \
    curl -fL --retry 3 \
        https://download.oracle.com/otn_software/linux/instantclient/1926000/instantclient-sdk-linux.x64-19.26.0.0.0dbru.zip \
        -o /tmp/oracle/instantclient-sdk.zip; \
    unzip -q /tmp/oracle/instantclient-basic.zip -d /tmp/oracle/basic; \
    unzip -q /tmp/oracle/instantclient-sdk.zip -d /tmp/oracle/sdk; \
    cp -a /tmp/oracle/basic/instantclient_19_26/. /usr/local/instantclient_19_26/; \
    cp -a /tmp/oracle/sdk/instantclient_19_26/. /usr/local/instantclient_19_26/; \
    ln -sfn /usr/local/instantclient_19_26 /usr/local/instantclient; \
    echo "/usr/local/instantclient" > /etc/ld.so.conf.d/oracle-instantclient.conf; \
    ldconfig; \
    mkdir -p /usr/local/instantclient/network/admin; \
    curl -fL --retry 3 \
        https://pecl.php.net/get/oci8-3.4.1.tgz \
        -o /tmp/oci8.tgz; \
    mkdir -p /tmp/oci8-build; \
    tar -xzf /tmp/oci8.tgz -C /tmp/oci8-build --strip-components=1; \
    cd /tmp/oci8-build; \
    phpize8.3; \
    ./configure \
        --with-php-config=/usr/bin/php-config8.3 \
        --with-oci8=instantclient,/usr/local/instantclient; \
    make -j"$(nproc)"; \
    make install; \
    echo "extension=oci8.so" > /etc/php/8.3/mods-available/oci8.ini; \
    phpenmod -v 8.3 -s cli oci8; \
    phpenmod -v 8.3 -s fpm oci8; \
    rm -rf \
        /tmp/oracle \
        /tmp/oci8-build \
        /tmp/oci8.tgz \
        /usr/local/instantclient/sdk \
        /usr/local/instantclient/include; \
    apt-get purge -y --auto-remove \
        autoconf \
        gcc \
        make \
        pkg-config \
        libc6-dev \
        zlib1g-dev \
        php8.3-dev; \
    rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# 3. Configure PHP
# ------------------------------------------------------------
COPY docker/php/php.ini /etc/php/8.3/cli/conf.d/99-base-image.ini
COPY docker/php/php.ini /etc/php/8.3/fpm/conf.d/99-base-image.ini

COPY docker/php/opcache.ini /etc/php/8.3/cli/conf.d/99-base-opcache.ini
COPY docker/php/opcache.ini /etc/php/8.3/fpm/conf.d/99-base-opcache.ini

COPY docker/php/www.conf /etc/php/8.3/fpm/pool.d/www.conf

# ------------------------------------------------------------
# 4. Install Composer dengan retry
# ------------------------------------------------------------
RUN set -eux; \
    curl --retry 5 \
         --retry-all-errors \
         --retry-delay 3 \
         --connect-timeout 20 \
         --max-time 120 \
         -fsSL https://composer.github.io/installer.sig \
         -o /tmp/composer-installer.sig; \
    curl --retry 5 \
         --retry-all-errors \
         --retry-delay 3 \
         --connect-timeout 20 \
         --max-time 120 \
         -fsSL https://getcomposer.org/installer \
         -o /tmp/composer-setup.php; \
    EXPECTED_SIGNATURE="$(cat /tmp/composer-installer.sig)"; \
    ACTUAL_SIGNATURE="$(php -r "echo hash_file('sha384', '/tmp/composer-setup.php');")"; \
    test "${EXPECTED_SIGNATURE}" = "${ACTUAL_SIGNATURE}"; \
    php /tmp/composer-setup.php \
        --install-dir=/usr/local/bin \
        --filename=composer; \
    rm -f /tmp/composer-installer.sig /tmp/composer-setup.php; \
    composer --version

# ------------------------------------------------------------
# 5. Configure Nginx, Supervisor and startup script
# ------------------------------------------------------------
COPY docker/nginx/default.conf /etc/nginx/conf.d/default.conf
COPY docker/supervisor/supervisord.conf /etc/supervisor/supervisord.conf
COPY docker/start.sh /usr/local/bin/start.sh

RUN set -eux; \
    chmod +x /usr/local/bin/start.sh; \
    usermod -aG www-data nginx; \
    rm -f /etc/nginx/conf.d/default.conf.bak; \
    mkdir -p \
        /var/www/html \
        /run/php \
        /run/supervisor \
        /usr/local/instantclient/network/admin; \
    printf '%s\n' 'DISABLE_OOB=ON' \
        > /usr/local/instantclient/network/admin/sqlnet.ora; \
    printf '%s\n' \
        '<!doctype html>' \
        '<html lang="en">' \
        '<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">' \
        '<title>PHP 8.3 Base Image</title></head>' \
        '<body><h1>PHP 8.3 Base Image Ready</h1><p>Nginx and PHP-FPM are running.</p></body>' \
        '</html>' \
        > /var/www/html/index.html; \
    chown -R www-data:www-data /var/www/html; \
    nginx -t; \
    php-fpm8.3 -tt; \
    php8.3 -v; \
    php8.3 --ri oci8

WORKDIR /var/www/html

EXPOSE 80

STOPSIGNAL SIGQUIT

CMD ["/usr/local/bin/start.sh"]
