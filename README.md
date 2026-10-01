# ELOG for Home Assistant

[![Add repository to Home Assistant][repo-badge]][repo-link]
[![Build](https://github.com/__GH_USER__/__GH_REPO__/actions/workflows/build.yaml/badge.svg)](https://github.com/__GH_USER__/__GH_REPO__/actions/workflows/build.yaml)

Home Assistant app repository for [PSI ELOG](https://elog.psi.ch/elog/), a small
web-based electronic logbook. Runs in the sidebar via ingress, or directly on
port 8080.

## Install

1. Click the button above, or go to **Settings → Apps → App store → ⋮ →
   Repositories** and add `https://github.com/__GH_USER__/__GH_REPO__`.
2. Find **ELOG** in the store, install, start, then open it from the sidebar.

See [elog/DOCS.md](elog/DOCS.md) for configuration.

## Apps in this repository

| App | Description |
|---|---|
| [ELOG](elog/) | Lightweight PSI ELOG electronic logbook server |

[repo-badge]: https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg
[repo-link]: https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2F__GH_USER__%2F__GH_REPO__
