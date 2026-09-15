#!/usr/bin/env bash
# Omarchy native Amiga screensaver — one-liner installer.
#
#   curl -fsSL https://raw.githubusercontent.com/avillagran/omarchy-amiga/native-v0.2/install.sh | bash
#
# Safe to re-run. `--uninstall` removes what this script installed and restores
# backed-up Omarchy state; user media (the demo pack) is always preserved.

set -euo pipefail

TAG=native-v0.2
REPO=avillagran/omarchy-amiga
BASE_URL="https://github.com/$REPO/releases/download/$TAG"

RUNTIME_X86_64_SHA=a1967aa11bca5ed018defe4d0b0d171d4ac90de60baf1f9d15e701a01ddafb3a
RUNTIME_AARCH64_SHA=2118ee43103163991676a90b329db90060a0c502170493082a5ece6f05e1e9d6
PACK_SHA=6c38d7ed2c289c4eaa352af5e6a8128a950329a223a64dfc2bc9693ce73b6f08

OMARCHY_DIR=${OMARCHY_DIR:-$HOME/.config/omarchy}
STATE_DIR=${XDG_STATE_HOME:-$HOME/.local/state}/omarchy
BACKUP_DIR="$STATE_DIR/amiga-install-backups"
RUNTIME_DIR=$HOME/.local/lib/omarchy-amiga-runtime
PACK_DIR=$HOME/Wallpapers/AMIGA
PLUGIN_MARKER=.omarchy-amiga-native

log() { printf 'amiga-install: %s\n' "$*"; }
fail() { printf 'amiga-install: ERROR: %s\n' "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

fetch() { # fetch <url> <dest>
  if have curl; then curl -fsSL "$1" -o "$2";
  elif have wget; then wget -qO "$2" "$1";
  else fail 'curl or wget is required'; fi
}

verify_sha() { # verify_sha <file> <expected>
  local actual
  actual=$(sha256sum "$1" | cut -d' ' -f1)
  [[ $actual == "$2" ]] || fail "sha256 mismatch for $1 ($actual)"
}

require_tools() {
  local missing=()
  for tool in python3 tar sha256sum; do
    have "$tool" || missing+=("$tool")
  done
  have zstd || tar --zstd --version >/dev/null 2>&1 || missing+=('zstd')
  ( have curl || have wget ) || missing+=('curl or wget')
  ((${#missing[@]} == 0)) || fail "missing tools: ${missing[*]}"
}

runtime_asset_for() {
  case "$(uname -m)" in
  x86_64) echo "$BASE_URL/omarchy-amiga-runtime-x86_64.tar.zst" ;;
  aarch64 | arm64) echo "$BASE_URL/omarchy-amiga-runtime-aarch64.tar.zst" ;;
  *) fail "unsupported architecture: $(uname -m)" ;;
  esac
}

runtime_sha_for() {
  case "$(uname -m)" in
  x86_64) echo "$RUNTIME_X86_64_SHA" ;;
  aarch64 | arm64) echo "$RUNTIME_AARCH64_SHA" ;;
  esac
}

backup_once() { # backup_once <file> — keep first copy only
  local file=$1 name
  [[ -f $file ]] || return 0
  name=$(basename "$file")
  if [[ ! -f $BACKUP_DIR/$name.orig ]]; then
    cp -a "$file" "$BACKUP_DIR/$name.orig"
  fi
}

# ---------------------------------------------------------------- install ---

install_runtime() {
  local url sha tmp staging
  url=$(runtime_asset_for)
  sha=$(runtime_sha_for)
  tmp=$(mktemp --suffix=.tar.zst)
  log "downloading runtime ($(uname -m))"
  fetch "$url" "$tmp"
  verify_sha "$tmp" "$sha"

  staging=$(mktemp -d)
  tar --zstd -xf "$tmp" -C "$staging"
  python3 "$staging/omarchy-amiga-runtime/controller/state.py" --check-runtime \
    || fail 'downloaded runtime failed its own integrity check'

  if [[ -d $RUNTIME_DIR ]]; then
    log "replacing existing runtime (backup in $BACKUP_DIR)"
    mkdir -p "$BACKUP_DIR"
    tar --zstd -cf "$BACKUP_DIR/runtime-pre-$TAG-$(date +%Y%m%d-%H%M%S).tar.zst" \
      -C "$HOME/.local/lib" omarchy-amiga-runtime
    rm -rf "$RUNTIME_DIR"
  fi
  mkdir -p "$(dirname "$RUNTIME_DIR")"
  cp -a "$staging/omarchy-amiga-runtime" "$RUNTIME_DIR"
  python3 "$RUNTIME_DIR/controller/state.py" --check-runtime \
    || fail 'installed runtime failed integrity check'
  rm -rf "$staging" "$tmp"
  log 'runtime installed and verified'
}

install_wrapper() {
  mkdir -p "$HOME/.local/bin"
  cat > "$HOME/.local/bin/omarchy-screensaver-amiga" <<'WRAPPER'
#!/bin/bash

# omarchy:summary=Run the native FS-UAE Amiga Demos screensaver
# omarchy:args=[--check]
# omarchy:hidden=true

controller="$OMARCHY_PATH/shell/plugins/services/idle/state.py"
if [[ ! -f $controller ]]; then
  if [[ -d /usr/lib/omarchy-amiga-runtime ]]; then
    controller="/usr/lib/omarchy-amiga-runtime/controller/state.py"
  else
    controller="$HOME/.local/lib/omarchy-amiga-runtime/controller/state.py"
  fi
fi
exec python3 "$controller" "$@"
WRAPPER
  chmod 755 "$HOME/.local/bin/omarchy-screensaver-amiga"
  log 'wrapper installed to ~/.local/bin/omarchy-screensaver-amiga'
}

install_plugin() {
  local plugins_dir=$OMARCHY_DIR/plugins
  mkdir -p "$plugins_dir" "$BACKUP_DIR"

  # Reuse an existing native Amiga idle clone (e.g. kuyen.idle) when present;
  # otherwise create a fresh plugin directory.
  local target=''
  for dir in "$plugins_dir"/*.idle; do
    [[ -d $dir ]] || continue
    if grep -q 'amigaPresent' "$dir/native-v1/Service.qml" 2>/dev/null; then
      target=$dir
      break
    fi
  done

  if [[ -z $target ]]; then
    target=$plugins_dir/omarchy-amiga-native.idle
    log "creating new plugin at $target"
  else
    log "updating existing native plugin $(basename "$target")"
  fi
  mkdir -p "$target/native-v1"

  local archive tmp
  tmp=$(mktemp --suffix=.tar.zst)
  fetch "$BASE_URL/omarchy-amiga-plugin.tar.zst" "$tmp"
  archive=$(mktemp -d)
  tar --zstd -xf "$tmp" -C "$archive"
  local file
  for file in Service.qml AmigaScreensaver.qml IdleModel.js; do
    [[ -f $archive/plugin/$file ]] || fail "plugin archive is missing $file"
    cp -a "$archive/plugin/$file" "$target/$file"
    cp -a "$archive/plugin/$file" "$target/native-v1/$file"
  done
  rm -rf "$archive" "$tmp"

  if [[ ! -f $target/manifest.json ]]; then
    local id
    id=$(basename "$target")
    cat > "$target/manifest.json" <<MANIFEST
{
  "schemaVersion": 1,
  "id": "$id",
  "name": "Amiga Native Idle",
  "version": "1.0.0",
  "author": "avillagran",
  "description": "Quickshell idle detection with the native FS-UAE Amiga screensaver.",
  "kinds": ["service"],
  "keepLoaded": true,
  "entryPoints": { "service": "native-v1/Service.qml" },
  "omarchy": { "clonedFrom": "omarchy.idle" }
}
MANIFEST
  fi
  touch "$target/$PLUGIN_MARKER"

  # Enable our plugin and disable conflicting idle services / the legacy
  # Amiga plugin, preserving every other shell.json entry.
  backup_once "$OMARCHY_DIR/shell.json"
  local plugin_id
  plugin_id=$(python3 -c "import json;print(json.load(open('$target/manifest.json'))['id'])")
  python3 - "$OMARCHY_DIR/shell.json" "$plugin_id" <<'PY'
import json, sys
path, plugin_id = sys.argv[1], sys.argv[2]
try:
    data = json.load(open(path))
except (OSError, ValueError):
    data = {}
plugins = data.get('plugins')
if isinstance(plugins, dict):  # future shape: id -> bool
    plugins[plugin_id] = True
    for conflicting in ('omarchy.idle', 'io.github.avillagran.omarchy-amiga'):
        if plugins.get(conflicting):
            plugins[conflicting] = False
elif isinstance(plugins, list):  # current shape: enabled ids
    if plugin_id not in plugins:
        plugins.append(plugin_id)
    plugins[:] = [p for p in plugins
                  if p not in ('omarchy.idle', 'io.github.avillagran.omarchy-amiga')]
else:
    data['plugins'] = [plugin_id]
json.dump(data, open(path, 'w'), indent=2)
PY
  log "plugin $plugin_id enabled in shell.json"
}

install_pack() {
  if [[ -f $PACK_DIR/SHA256SUMS ]]; then
    log 'pack already present; verifying checksums in place'
    (cd "$PACK_DIR" && sha256sum -c --quiet SHA256SUMS) \
      || fail 'existing pack failed checksum verification (move it away and re-run)'
    return 0
  fi
  log 'downloading demo pack (31 demos, ~29 MB)'
  local tmp staging
  tmp=$(mktemp --suffix=.tar.zst)
  fetch "https://github.com/avillagran/omarchy-animated-background/releases/download/amiga-pack-v0.2/amiga-pack-native.tar.zst" "$tmp"
  verify_sha "$tmp" "$PACK_SHA"
  staging=$(mktemp -d)
  tar --zstd -xf "$tmp" -C "$staging"
  (cd "$staging/AMIGA" && sha256sum -c --quiet SHA256SUMS) \
    || fail 'downloaded pack failed checksum verification'
  mkdir -p "$PACK_DIR"
  cp -a "$staging/AMIGA/." "$PACK_DIR/"
  rm -rf "$staging" "$tmp"
  log "pack installed to $PACK_DIR ($(ls -d "$PACK_DIR"/*/ | wc -l) demos)"
}

select_screensaver() {
  rm -rf "$HOME/.cache/quickshell/qmlcache" 2>/dev/null || true
  if have omarchy-setup-screensaver; then
    # Persists selection only after the full readiness check (runtime, pack,
    # native idle service IPC) passes.
    if omarchy-setup-screensaver amiga; then
      log 'screensaver selection persisted: amiga'
    else
      log 'WARNING: omarchy-setup-screensaver amiga did not pass yet (idle service may need a shell reload). Selection not persisted.'
    fi
  else
    backup_once "$OMARCHY_DIR/screensaver"
    printf 'amiga\n' > "$OMARCHY_DIR/screensaver"
    log 'screensaver selection written: amiga'
  fi
}

do_install() {
  require_tools
  mkdir -p "$BACKUP_DIR"
  install_runtime
  install_wrapper
  install_plugin
  install_pack
  select_screensaver
  log 'done. The screensaver launches on idle, or force it with: omarchy-launch-screensaver force'
}

# --------------------------------------------------------------- uninstall ---

do_uninstall() {
  rm -f "$HOME/.local/bin/omarchy-screensaver-amiga"
  log 'wrapper removed'

  if [[ -d $RUNTIME_DIR ]]; then
    tar --zstd -cf "$BACKUP_DIR/runtime-removed-$(date +%Y%m%d-%H%M%S).tar.zst" \
      -C "$HOME/.local/lib" omarchy-amiga-runtime
    rm -rf "$RUNTIME_DIR"
    log 'runtime removed (archived in backups)'
  fi

  local plugins_dir=$OMARCHY_DIR/plugins
  for dir in "$plugins_dir"/*.idle; do
    [[ -f $dir/$PLUGIN_MARKER ]] || continue
    if [[ $(find "$dir" -name '*.qml' -o -name '*.js' | wc -l) -le 6 ]]; then
      # Plugin directory was created by this installer: remove it entirely.
      rm -rf "$dir"
      log "removed plugin $(basename "$dir")"
    else
      # Pre-existing clone we overlaid: keep it but stop claiming it.
      rm -f "$dir/$PLUGIN_MARKER"
      log "left pre-existing plugin $(basename "$dir") in place (marker removed)"
    fi
  done

  if [[ -f $BACKUP_DIR/shell.json.orig ]]; then
    cp -a "$BACKUP_DIR/shell.json.orig" "$OMARCHY_DIR/shell.json"
    log 'shell.json restored from backup'
  fi
  if [[ -f $BACKUP_DIR/screensaver.orig ]]; then
    cp -a "$BACKUP_DIR/screensaver.orig" "$OMARCHY_DIR/screensaver"
    log 'screensaver selection restored'
  fi
  rm -rf "$HOME/.cache/quickshell/qmlcache" 2>/dev/null || true
  log 'uninstall complete. Demo pack preserved at ~/Wallpapers/AMIGA.'
}

case "${1:-}" in
'') do_install ;;
--uninstall) do_uninstall ;;
*) echo "Usage: $0 [--uninstall]" >&2; exit 1 ;;
esac
