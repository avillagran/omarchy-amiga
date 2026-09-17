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

cat > "$tmp/shell.json" <<'JSON'
{"plugins":[{"id":"omarchy.idle"},{"id":"io.github.avillagran.omarchy-amiga"},{"id":"keep.me","option":true}]}
JSON
enable_plugin_in_shell_json "$tmp/shell.json" "omarchy-amiga-native.idle"
python3 - "$tmp/shell.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
plugins = data['plugins']
assert plugins == [
    {'id': 'keep.me', 'option': True},
    {'id': 'omarchy-amiga-native.idle'},
], plugins
assert data['disabledPlugins'] == ['omarchy.idle'], data
assert data['cloneSourceRestores'] == ['omarchy-amiga-native.idle'], data
PY

enable_plugin_in_shell_json "$tmp/shell.json" "omarchy-amiga-native.idle"
python3 - "$tmp/shell.json" <<'PY'
import json, sys
plugins = json.load(open(sys.argv[1]))['plugins']
assert sum(p.get('id') == 'omarchy-amiga-native.idle' for p in plugins) == 1, plugins
PY
