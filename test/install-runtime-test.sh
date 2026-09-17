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

root="$tmp/runtime"
mkdir -p "$root/controller" "$root/fs-uae"
printf '1\n' > "$root/fs-uae/FRAME_PROTOCOL"
cat > "$root/controller/runtime.py" <<'PY'
import os

def verify(root, required):
    with open(os.environ['VERIFY_LOG'], 'w') as stream:
        stream.write(str(root) + '\n')
        stream.write('\n'.join(required) + '\n')
PY

export VERIFY_LOG="$tmp/verified"
verify_staged_runtime "$root"
[[ $(sed -n '1p' "$VERIFY_LOG") == "$root" ]]
grep -qx 'fs-uae/bin/fs-uae' "$VERIFY_LOG"
grep -qx 'guard/Guard.qml' "$VERIFY_LOG"
