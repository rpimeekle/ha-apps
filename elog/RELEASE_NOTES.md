# ELOG v1.1.4

## Fixed

- **Sidebar panel showing "Invalid URL: app/General/".** Opening ELOG from Home Assistant could show this error page instead of your logbook. It happened when ELOG was opened from a page whose address starts with `/app/`.
- **404 after saving settings.** Saving changes on ELOG's **Config** page inside the panel ended on a "not found" page, even though the change itself had been saved.

Both problems had one cause. When no `url` option is set, ELOG builds its redirect addresses from the page the browser came from. Inside Home Assistant that is Home Assistant's own page, not ELOG's, so the redirects went to the wrong place. The app's proxy now hides that address from ELOG, so redirects stay inside the panel.

The direct web interface on port 8080 was not affected.

## Improved

- **Start-up self-test.** The self-test in the app log now checks for this problem too. If it finds it, it reports `Self-test ingress: PROBLEM` and explains why.
- **Accurate logbook list in the log.** The `Logbooks:` line at start-up now lists the logbooks elogd actually serves, read from `elogd.cfg`. Before, it always listed the logbooks from the app options, even when `manage_config` was off and the file had been edited by hand.

## Upgrading

No action is needed. Update the app and open the panel.

If you edit `elogd.cfg` by hand, keep these points in mind:

- **The options page stops applying.** With `manage_config: false`, the app leaves the whole file alone, `[global]` and every logbook section, and ignores the logbook and login settings on the options page. The options page doesn't update to match the file.
- **Turning `manage_config` back on overwrites the file.** At the next start, `elogd.cfg` is rebuilt from the app options and any hand edits are lost.
- **Renaming a logbook hides its old entries.** Entries are stored in a folder named after the logbook. To keep them, add `Subdir = <old name>` to the renamed section, or rename the folder under `/data/elog/logbooks/` while the app is stopped.
