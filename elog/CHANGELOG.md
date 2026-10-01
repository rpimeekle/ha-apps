# Changelog

## 1.1.0
- Sidebar panel through Home Assistant ingress (nginx path-rewriting proxy).
- Direct port 8080 kept as an option; can be disabled in Network settings.
- Graceful shutdown and failure propagation for elogd + proxy.
- GitHub Actions workflow publishing multi-arch images to GHCR.

## 1.0.0
- Initial release: ELOG built from source (CMake, master branch) on Debian bookworm.
- Logbooks, login, self-registration and URL configurable from the app options.
- Logbook data stored in /data (included in backups); elogd.cfg exposed in addon_configs.
