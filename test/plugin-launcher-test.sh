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
source "$tmp/functions.sh"

cat > "$tmp/Service.qml" <<'QML'
runProcess(screensaverProcess, "screensaver", "[[ $(omarchy-shell lock isLocked 2>/dev/null) == \"true\" ]] || omarchy-launch-screensaver")
QML
pin_plugin_launcher "$tmp/Service.qml"
grep -Fq '\"$HOME/.local/bin/omarchy-launch-screensaver\"' "$tmp/Service.qml"
! grep -Fq '|| omarchy-launch-screensaver' "$tmp/Service.qml"
pin_plugin_launcher "$tmp/Service.qml"
[[ $(grep -Fc '$HOME/.local/bin/omarchy-launch-screensaver' "$tmp/Service.qml") == 1 ]]
