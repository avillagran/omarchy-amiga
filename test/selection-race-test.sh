#!/usr/bin/env bash
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
python3 - "$repo/install.sh" "$tmp/functions.sh" <<'PY'
from pathlib import Path
import sys
text = Path(sys.argv[1]).read_text()
Path(sys.argv[2]).write_text(text.split('case "${1:-}" in', 1)[0])
PY
# shellcheck source=/dev/null
unset OMARCHY_PATH
source "$tmp/functions.sh"
[[ $OMARCHY_PATH == /usr/share/omarchy ]]

mkdir -p "$tmp/bin" "$tmp/home/.cache/quickshell/qmlcache"
cat > "$tmp/bin/omarchy-screensaver-amiga" <<'SH'
#!/bin/bash
exit 1
SH
cat > "$tmp/bin/omarchy-setup-screensaver" <<SH
#!/bin/bash
touch "$tmp/setup-was-called"
exit 0
SH
chmod +x "$tmp/bin/omarchy-screensaver-amiga" "$tmp/bin/omarchy-setup-screensaver"
HOME="$tmp/home" PATH="$tmp/bin:/usr/bin:/bin" AMIGA_READY_ATTEMPTS=1 select_screensaver
[[ ! -e $tmp/setup-was-called ]]
