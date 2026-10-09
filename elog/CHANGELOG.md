# Changelog

## 1.1.4

- Fixed the panel showing "Invalid URL: app/General/" and saving settings landing on a 404. ELOG was building its redirects from the Home Assistant page address; the proxy now hides that from ELOG.
- The start-up self-test now also checks for this problem.
- The "Logbooks:" line in the log now lists the logbooks from the actual config file, including hand-edited ones.

## 1.1.3

- Fixed the sidebar panel still not loading: redirects now stay inside Home Assistant instead of pointing to an internal address the browser can't reach.
- The start-up self-test now reports a clear OK/PROBLEM verdict for the panel.
- Updated documentation formatting, and logo issue

## 1.1.2

- Fixed the sidebar (ingress) panel spinning forever instead of loading ELOG.
- Added a start-up self-test and per-request proxy logging to make connection problems easy to diagnose.

## 1.1.1

- Added `setup.ps1` so the one-time repository setup works natively on Windows (PowerShell).
- Fixed `setup.sh` exiting silently in some cases; it now prints usage, reports each updated file, and detects an already-configured repo.
- Added `.gitattributes` to enforce LF line endings, preventing container start failures when committing from Windows.

## 1.1.0

- Sidebar panel through Home Assistant ingress (nginx path-rewriting proxy).
- Direct port 8080 kept as an option; can be disabled in Network settings.
- Graceful shutdown and failure propagation for elogd + proxy.
- GitHub Actions workflow publishing multi-arch images to GHCR.

## 1.0.0

- Initial release: ELOG built from source (CMake, master branch) on Debian bookworm.
- Logbooks, login, self-registration and URL configurable from the app options.
- Logbook data stored in /data (included in backups); elogd.cfg exposed in addon_configs.
