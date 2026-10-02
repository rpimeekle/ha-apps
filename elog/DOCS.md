# ELOG

ELOG is a small, self-contained web logbook from the Paul Scherrer Institute:
threaded entries, attributes, attachments, full-text search, no database.

## First start

1. Install and start the app. The first install compiles ELOG, so expect a few
   minutes (longer on a Raspberry Pi).
2. Enable **Show in sidebar** and open **ELOG** from the sidebar, or use
   **Open web UI** for the direct port (8080 by default).

## Two ways in

- **Sidebar (ingress)**: protected by your Home Assistant login, works through
  Nabu Casa / your HA reverse proxy with no extra ports.
- **Direct port 8080**: for people without a Home Assistant account, or for
  bookmarking ELOG on its own. It bypasses Home Assistant's login, so either
  turn on `authentication` or clear the port under the app's **Network**
  settings if you only want ingress.

## Options

| Option           | Meaning                                                                                                                |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `logbooks`       | List of logbooks (`name`, optional `description`). Each becomes a tab.                                                 |
| `authentication` | Require ELOG user accounts for all logbooks.                                                                           |
| `admin_user`     | Username that gets admin rights. **Register this name first.**                                                         |
| `self_register`  | 0 off · 1 open · 2 admin notified · 3 admin must approve.                                                              |
| `url`            | Optional external URL, e.g. `http://homeassistant.local:8080/`. Set it if redirects after saving go to the wrong host. |
| `manage_config`  | Regenerate `elogd.cfg` from these options on every start.                                                              |

### Turning on login

Set `authentication: true`, restart, open the UI and click **Register** to create
the account named in `admin_user`. Then lower `self_register` to `0` or `3` if
you don't want anyone else signing up.

## Advanced configuration

`elogd.cfg` lives in `/addon_configs/<slug>_elog/` (reachable through the
Samba or File editor apps). ELOG has hundreds of options; see the
[config reference](https://elog.psi.ch/elog/config.html).

To hand-edit it, set `manage_config: false` first, otherwise your edits are
overwritten at the next start. The same applies to changes made through ELOG's
own _Config_ page in the web UI.

## Data and backups

Entries, attachments and the password file are stored in the app's `/data`
folder and are included in Home Assistant backups.

## Notes

- Ingress works by rewriting ELOG's redirects, cookies and links on the fly.
  If a page ever jumps out of the panel or shows a 404, note which page and
  use the direct port meanwhile.
- No HTTPS inside the app. Put it behind your existing reverse proxy if you
  expose it outside your LAN.
- ELOG has no release tags; the image builds the current `master` branch. Set
  the `ELOG_REF` build argument in the Dockerfile to a commit hash to pin it.
