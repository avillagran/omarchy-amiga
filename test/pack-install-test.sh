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

old="$tmp/old/AMIGA"
new="$tmp/new/AMIGA"
mkdir -p "$old/old-demo" "$new/new-demo"
printf 'old\n' > "$old/old-demo/data"
printf 'new\n' > "$new/new-demo/data"
(cd "$old" && sha256sum old-demo/data > SHA256SUMS)
(cd "$new" && sha256sum new-demo/data > SHA256SUMS)
archive="$tmp/amiga-pack-native.tar.zst"
tar --zstd -cf "$archive" -C "$tmp/new" AMIGA

PACK_DIR="$tmp/installed/AMIGA"
mkdir -p "$(dirname "$PACK_DIR")"
cp -a "$old" "$PACK_DIR"
PACK_SHA=$(sha256sum "$archive" | cut -d' ' -f1)
PACK_INVENTORY_SHA=$(sha256sum "$new/SHA256SUMS" | cut -d' ' -f1)
PACK_PREVIOUS_INVENTORY_SHA=$(sha256sum "$old/SHA256SUMS" | cut -d' ' -f1)
fetch() {
  cp "$archive" "$2"
}
install_pack
[[ -f $PACK_DIR/new-demo/data ]]
[[ ! -e $PACK_DIR/old-demo ]]
[[ $(<"$PACK_DIR/new-demo/data") == new ]]

PACK_DIR="$tmp/custom/AMIGA"
mkdir -p "$PACK_DIR/custom-demo"
printf 'custom\n' > "$PACK_DIR/custom-demo/data"
(cd "$PACK_DIR" && sha256sum custom-demo/data > SHA256SUMS)
fetch() {
  return 99
}
install_pack
[[ $(<"$PACK_DIR/custom-demo/data") == custom ]]

echo 'pack install and safe upgrade: ok'
