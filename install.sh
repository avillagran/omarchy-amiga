#!/usr/bin/env bash
# Omarchy native Amiga screensaver — one-liner installer.
#
#   curl -fsSL https://raw.githubusercontent.com/avillagran/omarchy-amiga/native-v0.4.2/install.sh | bash
#
# Safe to re-run. `--uninstall` removes what this script installed and restores
# backed-up Omarchy state; user media (the demo pack) is always preserved.

set -euo pipefail

# The one-liner can run from a plain terminal or SSH session where Omarchy's
# graphical-session environment has not been imported yet.
export OMARCHY_PATH=${OMARCHY_PATH:-/usr/share/omarchy}

TAG=native-v0.4.2
REPO=avillagran/omarchy-amiga
BASE_URL="https://github.com/$REPO/releases/download/$TAG"

RUNTIME_X86_64_SHA=4dbbf4bf5534ed7d760d22f0e5c8b55bee38a7bfc33d45ef371da25331aa7362
RUNTIME_AARCH64_SHA=142183daf64c277a3e7e6be4387f38b1067d80ba027b0b51ee1d326e701097f8
PACK_SHA=6c38d7ed2c289c4eaa352af5e6a8128a950329a223a64dfc2bc9693ce73b6f08

OMARCHY_DIR=${OMARCHY_DIR:-$HOME/.config/omarchy}
STATE_DIR=${XDG_STATE_HOME:-$HOME/.local/state}/omarchy
BACKUP_DIR="$STATE_DIR/amiga-install-backups"
RUNTIME_DIR=$HOME/.local/lib/omarchy-amiga-runtime
PACK_DIR=$HOME/Wallpapers/AMIGA
PLUGIN_MARKER=.omarchy-amiga-native

# bin/omarchy-launch-screensaver from avillagran/omarchy @ 2e245dff. Stock
# Omarchy has no Amiga branch and its session PATH places /usr/share/omarchy/bin
# before ~/.local/bin, so the installed plugin/menu call this pinned user-local
# launcher explicitly instead of relying on command shadowing.
LAUNCHER_URL="https://raw.githubusercontent.com/avillagran/omarchy/2e245dff86de9c512e4fba266158857bb36434b6/bin/omarchy-launch-screensaver"
LAUNCHER_SHA=c17dc730f2eadeb8a8bbbe8dfa3a45f2bbca599506bd472d43f549d4a848417a
SETUP_URL="https://raw.githubusercontent.com/avillagran/omarchy/2e245dff86de9c512e4fba266158857bb36434b6/bin/omarchy-setup-screensaver"
SETUP_SHA=d422abfd17f8901aee010a3ceda1c6a3810512c30c410a83e8cc3f3791ad3be6

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

verify_staged_runtime() { # verify_staged_runtime <runtime-root>
  local root=$1
  PYTHONPATH="$root/controller" python3 - "$root" <<'PY'
import sys
import runtime

root = sys.argv[1]
required = (
    'fs-uae/FRAME_PROTOCOL', 'fs-uae/bin/fs-uae',
    'audio/libopenal.so.1', 'audio/libamiga-pulse.so',
    'bin/gl-probe', 'guard/AmigaInput/libamigainput.so',
    'guard/AmigaInput/qmldir', 'guard/Guard.qml',
)
runtime.verify(root, required)
PY
  [[ $(<"$root/fs-uae/FRAME_PROTOCOL") == 1 ]] \
    || fail 'FS-UAE frame protocol 1 is required; rebuild the private runtime'
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

plugin_revision() {
  local release=${TAG//./-}
  printf '%s-%s\n' "$release" "$(runtime_sha_for | cut -c1-12)"
}

backup_once() { # backup_once <file> — keep first copy only
  local file=$1 name
  [[ -f $file ]] || return 0
  name=$(basename "$file")
  if [[ ! -f $BACKUP_DIR/$name.orig ]]; then
    cp -a "$file" "$BACKUP_DIR/$name.orig"
  fi
}

enable_plugin_in_shell_json() { # enable_plugin_in_shell_json <shell.json> <plugin-id>
  python3 - "$1" "$2" <<'PY'
import json, sys
path, plugin_id = sys.argv[1], sys.argv[2]
try:
    data = json.load(open(path))
except (OSError, ValueError):
    data = {}
plugins = data.get('plugins')
conflicting = {'omarchy.idle', 'io.github.avillagran.omarchy-amiga'}
if isinstance(plugins, dict):  # future shape: id -> bool
    plugins[plugin_id] = True
    for plugin in conflicting:
        if plugins.get(plugin):
            plugins[plugin] = False
elif isinstance(plugins, list):  # current shapes: strings or {id: ...} entries
    object_shape = any(isinstance(entry, dict) for entry in plugins)
    def entry_id(entry):
        return entry.get('id') if isinstance(entry, dict) else entry
    plugins[:] = [entry for entry in plugins
                  if entry_id(entry) not in conflicting | {plugin_id}]
    plugins.append({'id': plugin_id} if object_shape else plugin_id)
else:
    data['plugins'] = [plugin_id]
disabled = data.get('disabledPlugins')
if not isinstance(disabled, list):
    disabled = []
disabled = [entry for entry in disabled if entry != plugin_id]
if 'omarchy.idle' not in disabled:
    disabled.append('omarchy.idle')
data['disabledPlugins'] = disabled
restores = data.get('cloneSourceRestores')
if not isinstance(restores, list):
    restores = []
if plugin_id not in restores:
    restores.append(plugin_id)
data['cloneSourceRestores'] = restores
json.dump(data, open(path, 'w'), indent=2)
PY
}

import_graphical_session_env() {
  [[ -n ${WAYLAND_DISPLAY:-} && -n ${XDG_RUNTIME_DIR:-} && \
     -n ${HYPRLAND_INSTANCE_SIGNATURE:-} && -n ${DBUS_SESSION_BUS_ADDRESS:-} ]] \
    && return 0
  local pid='' candidate key value
  local -a pids=()
  mapfile -t pids < <(pgrep -u "$UID" -x quickshell 2>/dev/null || true)
  for candidate in "${pids[@]}"; do
    [[ -r /proc/$candidate/environ && -r /proc/$candidate/cmdline ]] || continue
    if [[ $(tr '\0' ' ' < "/proc/$candidate/cmdline") == *"$OMARCHY_PATH/shell"* ]]; then
      pid=$candidate
      break
    fi
  done
  [[ -n $pid ]] || return 1

  for key in WAYLAND_DISPLAY XDG_RUNTIME_DIR HYPRLAND_INSTANCE_SIGNATURE DBUS_SESSION_BUS_ADDRESS; do
    [[ -n ${!key:-} ]] && continue
    value=$(python3 - "$pid" "$key" <<'PY'
from pathlib import Path
import sys

pid, key = sys.argv[1:]
for item in Path(f'/proc/{pid}/environ').read_bytes().split(b'\0'):
    name, separator, value = item.partition(b'=')
    if separator and name.decode(errors='ignore') == key:
        print(value.decode(errors='surrogateescape'))
        break
PY
)
    [[ -n $value ]] || continue
    printf -v "$key" '%s' "$value"
    export "$key"
  done
}

refresh_plugin_service() { # refresh_plugin_service <plugin-id>
  local plugin_id=$1
  have omarchy || return 1
  import_graphical_session_env || return 1
  omarchy plugin disable "$plugin_id" >/dev/null
  if ! omarchy plugin enable "$plugin_id" >/dev/null; then
    enable_plugin_in_shell_json "$OMARCHY_DIR/shell.json" "$plugin_id"
    return 1
  fi
  log "plugin $plugin_id hot-reloaded"
}

pin_plugin_launcher() { # pin_plugin_launcher <Service.qml>
  python3 - "$1" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text()
old = '|| omarchy-launch-screensaver")'
new = '|| \\"$HOME/.local/bin/omarchy-launch-screensaver\\"")'
pinned = '$HOME/.local/bin/omarchy-launch-screensaver'
if old in text:
    path.write_text(text.replace(old, new))
elif pinned not in text:
    raise SystemExit('Amiga idle service has no recognized screensaver launcher')
PY
}

pin_plugin_guard() { # pin_plugin_guard <Service.qml>
  python3 - "$1" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
old = 'amigaScreensaver.configure("file://" + directory + "/omarchy-amiga-runtime/guard/Guard.qml")'
new = 'amigaScreensaver.configure(Qt.resolvedUrl("guard/Guard.qml"))'
if old in text:
    path.write_text(text.replace(old, new))
elif new not in text:
    raise SystemExit('Amiga idle service has no recognized guard source')
PY
}

write_plugin_manifest() { # write_plugin_manifest <manifest> <fallback-id> <service-path>
  python3 - "$1" "$2" "$3" <<'PY'
import json
from pathlib import Path
import sys

path = Path(sys.argv[1])
fallback_id = sys.argv[2]
service_path = sys.argv[3]
try:
    data = json.loads(path.read_text())
except (OSError, ValueError):
    data = {}
plugin_id = data.get('id')
if not isinstance(plugin_id, str) or not plugin_id:
    plugin_id = fallback_id
data.update({
    'schemaVersion': 1,
    'id': plugin_id,
    'author': 'Andrés Villagrán <andres@villagranquiroz.cl>',
    'kinds': ['service'],
    'keepLoaded': True,
})
data.setdefault('name', 'Amiga Native Idle')
data.setdefault('version', '1.0.0')
data.setdefault('description', 'Quickshell idle detection with the native FS-UAE Amiga screensaver.')
data['entryPoints'] = {'service': service_path}
omarchy = data.get('omarchy')
if not isinstance(omarchy, dict):
    omarchy = {}
omarchy['clonedFrom'] = 'omarchy.idle'
data['omarchy'] = omarchy
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
PY
}

install_menu_entries() { # install_menu_entries <user-menu.jsonc>
  python3 - "$1" <<'PY'
import json, re, sys
path = sys.argv[1]
try:
    text = open(path).read()
except OSError:
    text = '{}'
text = re.sub(r'^\s*//.*$', '', text, flags=re.M)
text = re.sub(r',\s*([}\]])', r'\1', text)
try:
    data = json.loads(text)
except ValueError as error:
    raise SystemExit('invalid Omarchy menu extension: ' + str(error))
data.update({
    'style.screensaver.omarchy': {
        'icon': '󱄄', 'label': 'Default',
        'checked': 'omarchy-setup-screensaver --is-default',
        'action': 'omarchy-setup-screensaver default',
    },
    'style.screensaver.amiga': {
        'icon': '󰊗', 'label': 'Amiga',
        'checked': 'omarchy-setup-screensaver --is-amiga',
        'action': 'omarchy-setup-screensaver amiga',
    },
    'style.screensaver.preview': {
        'icon': '', 'label': 'Preview',
        'action': '"$HOME/.local/bin/omarchy-launch-screensaver" force',
    },
    'system.screensaver': {
        'action': '"$HOME/.local/bin/omarchy-launch-screensaver" force',
    },
})
with open(path, 'w') as stream:
    json.dump(data, stream, ensure_ascii=False, indent=2)
    stream.write('\n')
PY
}

install_menu() {
  local menu="$OMARCHY_DIR/extensions/omarchy-menu.jsonc"
  mkdir -p "${menu%/*}" "$BACKUP_DIR"
  if [[ -f $menu ]]; then
    backup_once "$menu"
  else
    touch "$BACKUP_DIR/omarchy-menu.jsonc.missing"
  fi
  install_menu_entries "$menu"
  log 'Style > Screensaver menu entries installed'
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
  verify_staged_runtime "$staging/omarchy-amiga-runtime" \
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
  local tmp
  tmp=$(mktemp)
  fetch "$LAUNCHER_URL" "$tmp"
  verify_sha "$tmp" "$LAUNCHER_SHA"
  mv "$tmp" "$HOME/.local/bin/omarchy-launch-screensaver"
  chmod 755 "$HOME/.local/bin/omarchy-launch-screensaver"

  tmp=$(mktemp)
  fetch "$SETUP_URL" "$tmp"
  verify_sha "$tmp" "$SETUP_SHA"
  mv "$tmp" "$HOME/.local/bin/omarchy-setup-screensaver"
  chmod 755 "$HOME/.local/bin/omarchy-setup-screensaver"

  cat > "$HOME/.local/bin/omarchy-screensaver-amiga" <<'WRAPPER'
#!/bin/bash

# omarchy:summary=Run the native FS-UAE Amiga Demos screensaver
# omarchy:args=[--check]
# omarchy:hidden=true

export OMARCHY_PATH=${OMARCHY_PATH:-/usr/share/omarchy}
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
  log 'launcher, selector and wrapper installed to ~/.local/bin'
}

install_plugin() {
  local plugins_dir=$OMARCHY_DIR/plugins
  mkdir -p "$plugins_dir" "$BACKUP_DIR"

  # Reuse an existing native Amiga idle clone (e.g. kuyen.idle) when present;
  # otherwise create a fresh plugin directory.
  local target='' replacing_existing=false
  for dir in "$plugins_dir"/*.idle; do
    [[ -d $dir ]] || continue
    if grep -q 'amigaPresent' "$dir/Service.qml" 2>/dev/null; then
      target=$dir
      replacing_existing=true
      break
    fi
  done

  if [[ -z $target ]]; then
    target=$plugins_dir/omarchy-amiga-native.idle
    log "creating new plugin at $target"
  else
    log "updating existing native plugin $(basename "$target")"
  fi
  # A fresh component URL is required for each release. The running QML engine
  # can retain an older Service.qml API when an enabled plugin reuses the same
  # entrypoint path, even after the source file and disk cache are replaced.
  local revision
  revision=$(plugin_revision)
  local service_dir=$target/$revision
  mkdir -p "$service_dir"

  local archive tmp
  tmp=$(mktemp --suffix=.tar.zst)
  fetch "$BASE_URL/omarchy-amiga-plugin.tar.zst" "$tmp"
  archive=$(mktemp -d)
  tar --zstd -xf "$tmp" -C "$archive"
  local file
  for file in Service.qml AmigaScreensaver.qml IdleModel.js; do
    [[ -f $archive/plugin/$file ]] || fail "plugin archive is missing $file"
    cp -a "$archive/plugin/$file" "$target/$file"
    cp -a "$archive/plugin/$file" "$service_dir/$file"
  done
  pin_plugin_launcher "$target/Service.qml"
  pin_plugin_launcher "$service_dir/Service.qml"
  [[ -f $RUNTIME_DIR/guard/Guard.qml ]] || fail 'installed runtime is missing Guard.qml'
  rm -rf "$service_dir/guard"
  cp -a "$RUNTIME_DIR/guard" "$service_dir/guard"
  pin_plugin_guard "$service_dir/Service.qml"
  rm -rf "$archive" "$tmp"

  write_plugin_manifest "$target/manifest.json" "$(basename "$target")" "$revision/Service.qml"
  touch "$target/$PLUGIN_MARKER"

  # Enable our plugin and disable conflicting idle services / the legacy
  # Amiga plugin, preserving every other shell.json entry.
  backup_once "$OMARCHY_DIR/shell.json"
  local plugin_id
  plugin_id=$(python3 -c "import json;print(json.load(open('$target/manifest.json'))['id'])")
  enable_plugin_in_shell_json "$OMARCHY_DIR/shell.json" "$plugin_id"
  log "plugin $plugin_id enabled in shell.json"
  if [[ $replacing_existing == true ]]; then
    refresh_plugin_service "$plugin_id" \
      || fail "could not hot-reload updated plugin $plugin_id"
  fi
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
    # A freshly enabled clone hot-loads asynchronously. Preflight here before
    # calling the interactive selector: its not-ready path opens a floating
    # installer terminal and would make this installer wait on that window.
    local ready=false attempts=${AMIGA_READY_ATTEMPTS:-20}
    for ((attempt = 0; attempt < attempts; attempt++)); do
      if omarchy-screensaver-amiga --check >/dev/null 2>&1; then
        ready=true
        break
      fi
      sleep .25
    done
    if [[ $ready == true ]] && omarchy-setup-screensaver amiga; then
      log 'screensaver selection persisted: amiga'
    else
      log 'WARNING: Amiga is installed, but the idle service did not become ready yet. Selection was not changed.'
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
  install_menu
  install_pack
  select_screensaver
  log 'done. The screensaver launches on idle, or force it with: omarchy-launch-screensaver force'
}

# --------------------------------------------------------------- uninstall ---

do_uninstall() {
  rm -f "$HOME/.local/bin/omarchy-screensaver-amiga" \
    "$HOME/.local/bin/omarchy-launch-screensaver" \
    "$HOME/.local/bin/omarchy-setup-screensaver"
  log 'wrapper, launcher and selector removed'

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
  if [[ -f $BACKUP_DIR/omarchy-menu.jsonc.orig ]]; then
    cp -a "$BACKUP_DIR/omarchy-menu.jsonc.orig" "$OMARCHY_DIR/extensions/omarchy-menu.jsonc"
    log 'menu extension restored'
  elif [[ -f $BACKUP_DIR/omarchy-menu.jsonc.missing ]]; then
    rm -f "$OMARCHY_DIR/extensions/omarchy-menu.jsonc"
    log 'installed menu extension removed'
  fi
  rm -rf "$HOME/.cache/quickshell/qmlcache" 2>/dev/null || true
  log 'uninstall complete. Demo pack preserved at ~/Wallpapers/AMIGA.'
}

case "${1:-}" in
'') do_install ;;
--uninstall) do_uninstall ;;
*) echo "Usage: $0 [--uninstall]" >&2; exit 1 ;;
esac
