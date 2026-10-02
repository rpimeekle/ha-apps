# DokuWiki

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]

A lightweight, database-free wiki that lives right in your Home Assistant sidebar.

Ideal for house documentation: where the stopcock is, how the heating schedule
works, wiring notes for your ESP32 projects, printer profiles, manuals, passwords
for guests' Wi-Fi... all as plain text files that are part of your backups.

- Official DokuWiki release on nginx + PHP-FPM (no database)
- Opens in the sidebar through Home Assistant ingress, with optional direct port
- Pages, media, users and plugins stored in `/addon_configs`, so they are
  visible over Samba and included in backups
- Plugin & template manager works and survives updates
- Safe in-place upgrades of DokuWiki when the app updates

See the **Documentation** tab for setup details.

[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
