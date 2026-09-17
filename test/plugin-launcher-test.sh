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

TAG=native-v9.8
runtime_sha_for() { printf '%s\n' abcdef1234567890; }
[[ $(plugin_revision) == native-v9-8-abcdef123456 ]]

cat > "$tmp/Service.qml" <<'QML'
runProcess(screensaverProcess, "screensaver", "[[ $(omarchy-shell lock isLocked 2>/dev/null) == \"true\" ]] || omarchy-launch-screensaver")
QML
pin_plugin_launcher "$tmp/Service.qml"
grep -Fq '\"$HOME/.local/bin/omarchy-launch-screensaver\"' "$tmp/Service.qml"
! grep -Fq '|| omarchy-launch-screensaver' "$tmp/Service.qml"
pin_plugin_launcher "$tmp/Service.qml"
[[ $(grep -Fc '$HOME/.local/bin/omarchy-launch-screensaver' "$tmp/Service.qml") == 1 ]]

cat >> "$tmp/Service.qml" <<'QML'
return amigaScreensaver.configure("file://" + directory + "/omarchy-amiga-runtime/guard/Guard.qml")
QML
pin_plugin_guard "$tmp/Service.qml"
grep -Fq 'Qt.resolvedUrl("guard/Guard.qml")' "$tmp/Service.qml"
! grep -Fq 'omarchy-amiga-runtime/guard/Guard.qml' "$tmp/Service.qml"

cat > "$tmp/manifest.json" <<'JSON'
{
  "schemaVersion": 1,
  "id": "avillagran.idle",
  "name": "My Idle",
  "version": "1.0.0",
  "author": "Omarchy",
  "kinds": ["service"],
  "entryPoints": {"service": "native-v1/Service.qml"},
  "omarchy": {"clonedFrom": "omarchy.idle"}
}
JSON
write_plugin_manifest "$tmp/manifest.json" "fallback.id" "native-v9-8/Service.qml"
python3 - "$tmp/manifest.json" <<'PY'
import json
import sys

manifest = json.load(open(sys.argv[1]))
assert manifest['id'] == 'avillagran.idle'
assert manifest['author'] == 'Andrés Villagrán <andres@villagranquiroz.cl>'
assert manifest['entryPoints']['service'] == 'native-v9-8/Service.qml'
assert manifest['omarchy']['clonedFrom'] == 'omarchy.idle'
PY

mkdir -p "$tmp/bin"
cat > "$tmp/bin/omarchy" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >> "$AMIGA_TEST_COMMANDS"
SH
chmod +x "$tmp/bin/omarchy"
export PATH="$tmp/bin:$PATH"
export AMIGA_TEST_COMMANDS="$tmp/commands"
export WAYLAND_DISPLAY=wayland-test
export XDG_RUNTIME_DIR="$tmp/runtime"
export HYPRLAND_INSTANCE_SIGNATURE=test-instance
export DBUS_SESSION_BUS_ADDRESS=unix:path=test
refresh_plugin_service avillagran.idle
mapfile -t commands < "$AMIGA_TEST_COMMANDS"
[[ ${commands[0]} == 'plugin disable avillagran.idle' ]]
[[ ${commands[1]} == 'plugin enable avillagran.idle' ]]
