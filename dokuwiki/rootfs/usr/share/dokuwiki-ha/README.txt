DokuWiki for Home Assistant - persistent storage
================================================

This folder holds everything that makes up your wiki. It is included in
backups of the DokuWiki app and is safe to browse via Samba / File editor.

  conf/      Settings. Put your own changes in local.php, *.local.conf,
             users.auth.php and acl.auth.php. Default files (dokuwiki.php,
             mime.conf, ...) are refreshed automatically on app updates.
  data/      Pages (data/pages/*.txt), media (data/media), page history
             (data/attic) and DokuWiki's caches, indexes and logs.
  plugins/   Bundled and installed plugins (lib/plugins).
  tpl/       Bundled and installed templates (lib/tpl).

  .dokuwiki-version   DokuWiki release these files were last aligned with.

Stop the app before editing files here by hand.
