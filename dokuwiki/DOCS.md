# DokuWiki for Home Assistant

## First start

1. Install the app and press **Start**. The first build takes a few minutes
   on a Raspberry Pi because the image is built locally.
2. Open it from the sidebar (**Wiki**) or with **Open Web UI**.
3. You land on DokuWiki's installer. Choose a wiki name, create your
   **superuser** (admin) account and pick an ACL policy:
   - *Closed wiki* – only logged-in users can read and edit (recommended if
     you enable the direct port).
   - *Public wiki* / *Open wiki* – fine for sidebar-only use, since Home
     Assistant already requires a login to reach the sidebar.
4. Save. The installer is removed automatically the next time the app starts.

## Where your wiki lives

Everything is stored in the app's public config folder, which you can reach via
the Samba or File editor apps as `/addon_configs/<id>_dokuwiki/`:

| Folder     | Contents |
|------------|----------|
| `conf/`    | Settings, users (`users.auth.php`) and permissions (`acl.auth.php`) |
| `data/`    | Pages (`data/pages/*.txt`), media, history, caches, logs |
| `plugins/` | Bundled and installed plugins |
| `tpl/`     | Bundled and installed templates |

This folder is included when you back up the app (or take a full backup).
Pages are plain text, so you can also edit them directly – stop the app
first to avoid clashing with an open editor.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `upload_limit_mb` | `64` | Largest file you can upload to the media manager. |
| `memory_limit_mb` | `256` | PHP memory per request. Raise only if you see memory errors. |

The wiki uses Home Assistant's time zone automatically.

## Direct access (optional)

By default the wiki is only reachable through the sidebar, behind your Home
Assistant login. To reach it directly (e.g. `http://homeassistant.local:8080`)
set a host port under **Configuration → Network**.

> **Note:** direct access bypasses Home Assistant's login. Use the *Closed
> wiki* ACL policy and strong passwords, and do not forward this port to the
> internet.

Feeds (RSS) and links inside notification e-mails use relative URLs when
generated through the sidebar. If you rely on them, enable the direct port and
set **Admin → Configuration → baseurl** to your direct address.

## Plugins and templates

Use **Admin → Extension Manager** as usual; installs land in `plugins/` and
`tpl/` and persist across restarts and updates.

Do **not** use the *upgrade* plugin to update DokuWiki itself. The DokuWiki
core is part of this app's image – update the app instead.

## Updates

When a new app version ships a newer DokuWiki release, the app on start:

- refreshes DokuWiki's default config files (your own `local.php`,
  `*.local.conf`, users and ACL files are never touched),
- refreshes the bundled plugins and the default template,
- adds any new data folders without overwriting pages or media,
- removes files DokuWiki itself deleted in the new release (`data/deleted.files`).

Take a backup before updating, as with any app.

## Moving an existing DokuWiki here

1. Install and start the app once, then stop it.
2. Copy your old `data/pages`, `data/media`, `data/meta`, `data/attic`,
   `data/media_meta` and `data/media_attic` into the matching folders.
3. Copy your `conf/local.php`, `conf/users.auth.php`, `conf/acl.auth.php`,
   `conf/plugins.local.php` and any `*.local.conf` files into `conf/`.
4. Copy any non-bundled plugins / templates into `plugins/` and `tpl/`.
5. Start the app. File ownership is fixed automatically. Rebuild the search
   index from **Admin → Search Index** if you have the searchindex plugin, or
   just let DokuWiki re-index pages as they are visited.

## Nice URLs

The bundled nginx config supports DokuWiki's rewrite mode. Set
**Admin → Configuration → userewrite** to `.htaccess` for URLs like
`/heating/schedule` instead of `doku.php?id=heating:schedule`.

## Troubleshooting

- **Logs:** the app's **Log** tab shows nginx and PHP errors; DokuWiki's own
  log is in `data/log/`.
- **Upload fails:** raise `upload_limit_mb` and restart the app.
- **Start over:** stop the app, delete the contents of its
  `/addon_configs/<id>_dokuwiki/` folder and start it again.
