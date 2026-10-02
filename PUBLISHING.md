# Maintainer notes

## Repository layout

Every top-level folder containing a `config.yaml` is an app. Slugs must be
unique. Each app has its own `version`, `CHANGELOG.md` and image
(`ghcr.io/<owner>/<slug>`), and is released independently.

## Adding another app

1. Create `<slug>/` with `config.yaml`, `Dockerfile`, `DOCS.md`, `CHANGELOG.md`,
   `icon.png`, `logo.png` and `translations/en.yaml`.
2. Do not add a `repository.yaml` or `.github/` inside the app folder.
3. Add a row to the table in `README.md`.
4. Push. CI builds only the apps whose folders changed. A change to
   `.github/workflows/` rebuilds all of them.

## Releasing an update

Bump `version` in that app's `config.yaml` and add a `CHANGELOG.md` entry.
Home Assistant only offers an update when the version changes.

If an app uses pre-built images (`image:` set in `config.yaml`), the update
shows in HA as soon as the push lands. Installing it fails until CI has pushed
that tag, so merge version bumps once CI is green.

## GHCR package permissions

An image package that was first published from a *different* repository
won't accept pushes from this one (`403 permission_denied`). Fix it once per package:
GitHub → Packages → `<package>` → Package settings → **Manage Actions access**
→ add this repository with the **Write** role.

New packages start **private**. Set them to **Public** so Home Assistant can
pull them.
