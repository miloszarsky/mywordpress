# mywordpress

Hardened Apache + PHP-FPM 8.5 base image for WordPress, published to GHCR in
two variants that share the same configuration (`custom-php.ini`,
`apache-vhost.conf`) and behave identically at runtime.

## Variants

| Variant | Base image | Dockerfile | Tags | Size |
|---|---|---|---|---|
| Debian (default) | `debian:trixie-slim` | `Dockerfile` | `latest`, `2`, `2.1`, `2.1.0`, ... | ~430 MB |
| Alpine | `alpine:3.23` | `Dockerfile.alpine` | `latest-alpine`, `2-alpine`, `2.1-alpine`, `2.1.0-alpine`, ... | ~143 MB |

```sh
docker pull ghcr.io/miloszarsky/mywordpress:latest         # Debian
docker pull ghcr.io/miloszarsky/mywordpress:latest-alpine  # Alpine
```

Differences between the variants are packaging-only:

- **PHP source** — Debian installs PHP 8.5 from the [Sury](https://packages.sury.org/php/)
  repository; Alpine ships it natively in its community repository
  (OPcache + JIT is compiled into Alpine's base `php85` package).
- **Size / CVE surface** — the Alpine image is about a third of the size and
  typically scans with zero known CVEs; the Debian base carries the usual
  background of unfixed low-impact CVEs (reported, not blocking).
- **libc** — Alpine uses musl instead of glibc. Irrelevant for stock
  WordPress/PHP, worth knowing if you add binary extensions.

Everything else is kept in lockstep: same Apache event MPM fronting PHP-FPM
over a unix socket, same PHP extension set (mysqli, gd, curl, mbstring, xml,
zip, intl, soap, bcmath, exif, sodium, ...), same php.ini tuning
(OPcache + tracing JIT, 512M memory limit, hardened session cookies), same
vhost hardening (security response headers, blocked access to `wp-config.php`
/ `xmlrpc.php` / dotfiles, no PHP execution from `wp-content/uploads`), same
banner hardening, and the same tini entrypoint for clean shutdown.

## Usage

The image provides the PHP/Apache runtime only — WordPress itself is expected
at `/var/www/html` (bind mount or `COPY` in a derived image):

```sh
docker run -d -p 80:80 -v /path/to/wordpress:/var/www/html \
  ghcr.io/miloszarsky/mywordpress:latest-alpine
```

## OpenTelemetry tracing

Both variants ship distributed tracing for WordPress with zero changes to the
mounted site: the `opentelemetry` PHP extension (plus `protobuf` for fast OTLP
serialization) is installed from distro packages, and the [OTel PHP SDK with
WordPress auto-instrumentation](https://github.com/open-telemetry/opentelemetry-php-contrib)
is baked into the image at `/opt/otel-php`, loaded via `auto_prepend_file`.

Tracing is **off by default** (the prepend only registers a Composer
autoloader; the SDK stays no-op). Activate it with standard OTel env vars:

```sh
docker run -d -p 80:80 -v /path/to/wordpress:/var/www/html \
  -e OTEL_PHP_AUTOLOAD_ENABLED=true \
  -e OTEL_EXPORTER_OTLP_ENDPOINT=http://your-collector:4318 \
  -e OTEL_SERVICE_NAME=my-site \
  ghcr.io/miloszarsky/mywordpress:latest
```

| Variable | Image default | Meaning |
|---|---|---|
| `OTEL_PHP_AUTOLOAD_ENABLED` | `false` | Master switch — set `true` to trace. |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | *(unset)* | Your collector's OTLP endpoint (`http://host:4318` for HTTP). |
| `OTEL_SERVICE_NAME` | `wordpress` | `service.name` resource attribute. |
| `OTEL_TRACES_EXPORTER` | `otlp` | Traces only; metrics and logs exporters default to `none`. |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | `http/protobuf` | Export protocol. |

All other [SDK env vars](https://opentelemetry.io/docs/languages/sdk-configuration/)
work as usual (sampling, headers, resource attributes, ...) — PHP-FPM pools
are configured with `clear_env = no` in both variants so container env vars
reach the SDK.

Notes:

- The bundled SDK registers its autoloader for every request. If a plugin
  bundles conflicting versions of shared libraries (e.g. Guzzle), the
  image's copies win for their namespaces.
- The SDK bundle is built in a `composer:2` stage that is kept **identical**
  in both Dockerfiles — edit them together.

## CI / security scanning

Every push to `master` and every release builds **both** variants and scans
them with Trivy:

- **Blocking scan** — fails the build on HIGH/CRITICAL CVEs that have an
  upstream fix (actionable: rebuild picks up the fix).
- **Reporting scan** — uploads the full MEDIUM+ picture (including unfixed)
  to the GitHub Security tab without breaking the build.

Findings are separated per variant in the Security tab under the tool names
**Trivy (Debian)** and **Trivy (Alpine)**. Images are pushed to GHCR only on
release events; master pushes are scan-only.
