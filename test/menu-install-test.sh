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

cat > "$tmp/menu.jsonc" <<'JSONC'
{
  // Preserve existing user customization.
  "style.bootloader": {"label": "Bootloader"},
}
JSONC
install_menu_entries "$tmp/menu.jsonc"
python3 - "$tmp/menu.jsonc" <<'PY'
import json, re, sys
text = open(sys.argv[1]).read()
text = re.sub(r'^\s*//.*$', '', text, flags=re.M)
text = re.sub(r',\s*([}\]])', r'\1', text)
data = json.loads(text)
assert data['style.bootloader']['label'] == 'Bootloader'
assert data['style.screensaver.omarchy']['action'] == 'omarchy-setup-screensaver default'
assert data['style.screensaver.amiga']['action'] == 'omarchy-setup-screensaver amiga'
assert data['style.screensaver.preview']['action'] == '"$HOME/.local/bin/omarchy-launch-screensaver" force'
assert data['system.screensaver']['action'] == '"$HOME/.local/bin/omarchy-launch-screensaver" force'
PY

install_menu_entries "$tmp/menu.jsonc"
[[ $(grep -c '"style.screensaver.amiga"' "$tmp/menu.jsonc") == 1 ]]
