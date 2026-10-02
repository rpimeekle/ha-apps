# Changelog

## 1.0.1

- Updated the Home Assistant base image to Alpine 3.24 (`base:3.24-2026.08.0`), picking up the latest security fixes.
- Image metadata now links to the `ha-apps` repository.

## 1.0.0

- Initial release
- DokuWiki 2026-07-14c "Mort" on nginx + PHP 8.4 (Alpine 3.23 base)
- Home Assistant ingress (sidebar) support with optional direct port
- Persistent storage in `/addon_configs`, included in backups
- Automatic first-run installer redirect and installer clean-up
- Safe upgrade path for config defaults, bundled plugins and templates
- Options for upload size and PHP memory limit
