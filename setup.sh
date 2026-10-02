#!/usr/bin/env bash
# One-time: fill in your GitHub details (Linux, macOS, WSL or Git Bash).
#   ./setup.sh <github-user> [repo-name] ["Your Name <you@example.com>"]
# On Windows without bash, use setup.ps1 instead.
set -uo pipefail
if [ $# -lt 1 ]; then
  echo "usage: ./setup.sh <github-user> [repo-name] [\"Your Name <you@example.com>\"]" >&2
  exit 1
fi
USER_NAME="$1"
REPO="${2:-ha-elog}"
MAINT="${3:-${USER_NAME}}"
USER_LC="$(printf '%s' "${USER_NAME}" | tr '[:upper:]' '[:lower:]')"
YEAR="$(date +%Y)"
cd "$(dirname "$0")"

FILES="$(grep -rlE '__GH_USER(_LC)?__|__GH_REPO__|__MAINTAINER__|__YEAR__' \
         --exclude=setup.sh --exclude=setup.ps1 --exclude='*.png' --exclude-dir=.git . || true)"
if [ -z "${FILES}" ]; then
  echo "No placeholders found - this folder looks already configured."
  exit 0
fi
while read -r f; do
  sed -i.bak -e "s|__GH_USER_LC__|${USER_LC}|g" -e "s|__GH_USER__|${USER_NAME}|g" \
             -e "s|__GH_REPO__|${REPO}|g" -e "s|__MAINTAINER__|${MAINT}|g" \
             -e "s|__YEAR__|${YEAR}|g" "$f" && rm -f "$f.bak"
  echo "updated $f"
done <<< "${FILES}"
echo "Done. Repository URL: https://github.com/${USER_NAME}/${REPO}"
