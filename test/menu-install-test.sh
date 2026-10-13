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
  "style.screensaver": {"parent": "", "icon": "󱄄", "label": "Screensavers"},
  "style.screensaver.omarchy": {"icon": "󱄄", "label": "Default"},
  "style.screensaver.amiga": {"parent": "style.background", "label": "Amiga Demos"},
  "style.screensaver.review": {"icon": "󰍉", "label": "Review demos", "action": "\"$HOME/.local/bin/omarchy-amiga-review\""},
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
assert data['style.screensaver']['label'] == 'Screensaver'
assert 'parent' not in data['style.screensaver']
assert data['style.screensaver.text']['label'] == 'Set Animated Text'
assert data['style.screensaver.text']['checked'] == 'omarchy-setup-screensaver --is-default'
assert data['style.screensaver.text']['action'] == 'omarchy-setup-screensaver default'
assert data['style.screensaver.amiga']['label'] == 'Set Amiga Demos'
assert data['style.screensaver.amiga']['action'] == 'omarchy-setup-screensaver amiga'
assert 'parent' not in data['style.screensaver.amiga']
assert data['style.screensaver.preview']['action'] == '"$HOME/.local/bin/omarchy-launch-screensaver" force'
assert data['style.screensaver.restore-default']['action'] == 'omarchy-setup-screensaver default && omarchy-branding-screensaver reset'
assert data['style.screensaver.default']['when'] == 'false'
assert data['system.screensaver']['action'] == '"$HOME/.local/bin/omarchy-launch-screensaver" force'
assert 'style.screensaver.omarchy' not in data
assert 'style.screensaver.review' not in data
PY

install_menu_entries "$tmp/menu.jsonc"
[[ $(grep -c '"style.screensaver.amiga"' "$tmp/menu.jsonc") == 1 ]]
! grep -q 'style.screensaver.review' "$tmp/menu.jsonc"
! grep -q 'style.screensaver.omarchy' "$tmp/menu.jsonc"

echo 'menu install: ok'
