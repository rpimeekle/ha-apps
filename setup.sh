#!/usr/bin/env bash
# One-time: fill in your GitHub details.
#   ./setup.sh <github-user> [repo-name] ["Your Name <you@example.com>"]
set -euo pipefail
USER_NAME="${1:?usage: ./setup.sh <github-user> [repo-name] [maintainer]}"
REPO="${2:-ha-elog}"
MAINT="${3:-${USER_NAME}}"
USER_LC="$(printf '%s' "${USER_NAME}" | tr '[:upper:]' '[:lower:]')"
YEAR="$(date +%Y)"

grep -rlE '__GH_USER(_LC)?__|__GH_REPO__|__MAINTAINER__|__YEAR__' \
     --exclude=setup.sh --exclude-dir=.git . | while read -r f; do
  sed -i.bak -e "s|__GH_USER_LC__|${USER_LC}|g" -e "s|__GH_USER__|${USER_NAME}|g" \
             -e "s|__GH_REPO__|${REPO}|g" -e "s|__MAINTAINER__|${MAINT}|g" \
             -e "s|__YEAR__|${YEAR}|g" "$f"
  rm -f "$f.bak"
  echo "updated $f"
done
echo "Done. Repository URL: https://github.com/${USER_NAME}/${REPO}"
