# 🚀 Laravel-Ready PHP 8.3 Base Image (Debian Bookworm)

[![PHP Version](https://img.shields.io/badge/PHP-8.3-777BB4?style=for-the-badge&logo=php&logoColor=white)](https://www.php.net/)
[![Nginx Version](https://img.shields.io/badge/Nginx-1.30.6-009639?style=for-the-badge&logo=nginx&logoColor=white)](https://nginx.org/)
[![Debian Version](https://img.shields.io/badge/Debian-12%20(Bookworm)-A80030?style=for-the-badge&logo=debian&logoColor=white)](https://www.debian.org/)
[![Oracle OCI8](https://img.shields.io/badge/Oracle-OCI8%2019.26-F80000?style=for-the-badge&logo=oracle&logoColor=white)](https://www.oracle.com/database/technologies/instant-client.html)
[![Docker](https://img.shields.io/badge/Docker-Enabled-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)

A high-performance, **production-ready** Docker Base Image optimized for **Laravel / PHP 8.3** applications. This image combines **Nginx**, **PHP-FPM 8.3**, **Oracle Instant Client (OCI8)**, **Redis**, **Memcached**, and **Supervisor** into a single efficient container setup.

---

## ⚡ Key Features

- 🐧 **Base OS**: Debian 12 (`bookworm-slim`) — stable, secure, and lightweight.
- 🌐 **Web Server**: Nginx `1.30.6` (from official Nginx Debian repository).
- 🐘 **PHP 8.3**: PHP-FPM & CLI maintained by Ondřej Surý.
- 🗄️ **Oracle DB Support**: Pre-installed **Oracle Instant Client 19.26** & **OCI8 3.4.1** extension (configured with `DISABLE_OOB=ON` for stable cloud connection).
- 📦 **Rich PHP Extensions**: `bcmath`, `curl`, `gd`, `gmp`, `igbinary`, `imagick`, `intl`, `mbstring`, `memcached`, `msgpack`, `mysqli/pdo_mysql`, `opcache`, `pgsql/pdo_pgsql`, `redis`, `zip`, and `xml`.
- 🎼 **Composer**: Installed latest Composer with sha384 signature verification.
- ⚙️ **Process Management**: Supervisor manages Nginx and PHP-FPM in non-daemonized mode.
- 🛠️ **Laravel Optimized**: Default upload limit set to `100M`, memory limit `256M`, and pre-configured Nginx routing rules (`index.php`).

---

## 📁 Directory Structure

```text
.
├── docker/
│   ├── nginx/
│   │   └── default.conf            # Nginx Server Block & FastCGI Socket Config
│   ├── php/
│   │   ├── opcache.ini             # OPcache performance tuning
│   │   ├── php.ini                 # Custom PHP runtime settings
│   │   └── www.conf                # PHP-FPM pool configuration (Unix Socket)
│   ├── supervisor/
│   │   └── supervisord.conf        # Supervisor process controller config
│   └── start.sh                    # Container startup script & runtime initialization
├── Dockerfile                      # Multi-stage Docker build recipe
└── README.md                       # Documentation
```

---

## 🚀 Getting Started

### 1. Build the Image

Run the following command in the root directory:

```bash
docker build -t php83-nginx-oci8:latest .
```

### 2. Run the Container

Run a container instance mapped to port `8080`:

```bash
docker run -d \
  --name my-app \
  -p 8080:80 \
  -v $(pwd)/src:/var/www/html \
  php83-nginx-oci8:latest
```

Open your browser and navigate to `http://localhost:8080`.

---

## ⚙️ Environment Variables

You can customize runtime settings using environment variables:

| Variable | Default | Description |
| :--- | :--- | :--- |
| `TZ` | `Asia/Jakarta` | Container system timezone |
| `NGINX_AUTO_WORKERS` | `false` | When set to `true`, automatically sets Nginx `worker_processes` to match container CPU cores (`nproc`). |
| `TNS_ADMIN` | `/usr/local/instantclient/network/admin` | Path to Oracle network configuration directory (`tnsnames.ora`, `sqlnet.ora`). |

---

## 🔧 Usage as Base Image (Child Dockerfile)

Use this image as a base for building your custom Laravel project:

```dockerfile
FROM mgboydev/bookworm-nginx-php-oci8:8.3-1.0.0

# Copy application source code
COPY . /var/www/html

# Install Laravel dependencies
RUN composer install --no-dev --optimize-autoloader

# Set permissions for storage and cache directories
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

EXPOSE 80

CMD ["/usr/local/bin/start.sh"]
```

---

## 🛠️ Architecture & Performance Details

- 🔌 **FastCGI Unix Socket**: PHP-FPM communicates with Nginx via Unix socket `/run/php/php8.3-fpm.sock` for lower latency and better I/O performance compared to TCP ports.
- ⚡ **OPcache Tuned**: Pre-configured with `128MB` memory consumption and up to `20,000` accelerated files.
- 🪵 **Docker Native Logs**: Nginx and PHP-FPM logs are redirected directly to `stdout` and `stderr` for easy monitoring using `docker logs`.

---

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.
