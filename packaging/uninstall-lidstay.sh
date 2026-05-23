#!/usr/bin/env zsh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL_CLI="$REPO_ROOT/CLI/lidstay"
INSTALLED_CLI="/usr/local/bin/lidstay"

if [[ -x "$INSTALLED_CLI" ]]; then
  exec "$INSTALLED_CLI" uninstall "$@"
fi

if [[ -x "$LOCAL_CLI" ]]; then
  exec "$LOCAL_CLI" uninstall "$@"
fi

echo "Could not find the LidStay CLI."
echo "Remove /Applications/LidStay.app manually, then delete /usr/local/bin/lidstay if it exists."
exit 1
