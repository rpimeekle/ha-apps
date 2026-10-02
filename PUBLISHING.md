# Maintainer notes

## First publish

```bash
# Linux / macOS / WSL / Git Bash
./setup.sh <your-github-user> ha-elog "Your Name <you@example.com>"
# Windows PowerShell
.\setup.ps1 -User <your-github-user> -Maintainer "Your Name <you@example.com>"
git init -b main && git add -A && git commit -m "ELOG app 1.1.0"
gh repo create ha-elog --public --source=. --push   # or create it on github.com and push
```

The repository must be **public** for Home Assistant to add it.

## Local build vs. pre-built images

Out of the box `image:` is commented out in `elog/config.yaml`, so every
Home Assistant install compiles ELOG itself (a few minutes on x86, longer on a Pi).

The `Build` workflow builds amd64 + aarch64 on every push to `main` and publishes
`ghcr.io/<user>/elog:<version>`. To switch users to pre-built images:

1. Wait for the first successful run on the Actions tab.
2. GitHub → your profile → Packages → `elog` → Package settings →
   **Change visibility → Public**.
3. Uncomment the `image:` line in `elog/config.yaml`, bump `version`, push.

## Releasing an update

1. Change what you need, add a `CHANGELOG.md` entry, **bump `version`** in
   `elog/config.yaml`. Home Assistant only offers an update when the version changes.
2. Push to `main`. If you use pre-built images, the update appears in HA as soon
   as the push lands, but installing it fails until the workflow (~15–25 min,
   arm64 runs under emulation) has pushed that tag. Either wait before pushing the
   version bump, or work on a branch and merge when CI is green.

## Pinning ELOG

ELOG has no release tags. For reproducible builds set `ELOG_REF` in the
Dockerfile to a commit hash from https://bitbucket.org/ritt/elog/commits/.
