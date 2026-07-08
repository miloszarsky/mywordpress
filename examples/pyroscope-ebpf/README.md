# Continuous PHP profiling with Grafana Pyroscope (eBPF)

Host-level continuous profiling of the WordPress containers via
[Grafana Alloy](https://grafana.com/docs/alloy/latest/)'s `pyroscope.ebpf`
component. Runs on the Docker host as a privileged agent — **the WordPress
images need no changes** and pay no in-process overhead.

## Quickstart

```sh
# Point at your Pyroscope; the bundled pyroscope service is for local testing.
PYROSCOPE_URL=http://your-pyroscope:4040 docker compose up -d alloy
```

Then add Pyroscope as a datasource in Grafana (Drilldown → Profiles). Each
profiled container appears under its container name as `service_name`.

By default only containers whose name starts with `wordpress` or `wp`
(followed by `-`, `_` or `.`) are profiled — adjust the `keep` rule in
`config.alloy`.

## Requirements

- Kernel 5.10+ with BTF (`/sys/kernel/btf/vmlinux`) — any current distro,
  and WSL2 works.
- Alloy needs `pid: host` and `privileged` (or the capability list in the
  compose file), plus read-only mounts of the Docker socket and
  `/sys/kernel/tracing`.

## Known limitations (July 2026)

- **Alloy is pinned to v1.10.2.** v1.11.0+ switched to the
  otel-ebpf-profiler engine, which currently drops every sample with an
  empty container ID — no data reaches Pyroscope
  ([grafana/alloy#4921](https://github.com/grafana/alloy/issues/4921)).
  Verified broken on WSL2; possibly affects other hosts too. Symptom in
  debug logs: `pprof report successful count=0 total-size=0`.
- **v1.10.2 symbolizes native frames only**: flame graphs show PHP-FPM's C
  internals (`zend_execute`, `PHP_SHA256Update`, extension and libc/kernel
  frames) — good for engine/extension-level hotspots, but *not* PHP
  function names. The v1.11+ engine does full PHP interpreter unwinding
  (PHP 7.3–8.5, JIT included), so once #4921 is fixed, bumping the image
  upgrades the flame graphs to WordPress-level detail for free.
- For request-level tracing (which WordPress hook / DB query was slow) use
  the OpenTelemetry support built into the images — profiling and tracing
  complement each other.
