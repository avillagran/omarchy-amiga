#!/bin/bash
# Install or remove the Amiga demo plugin and its verified example media pack.
set -euo pipefail

REPOSITORY="https://github.com/avillagran/omarchy-amiga"
PLUGIN_ID="io.github.avillagran.omarchy-amiga"
PACK_URL="https://github.com/avillagran/omarchy-animated-background/releases/download/amiga-pack-v0.1/omarchy-amiga-demos-v0.1.zip"
PACK_SHA256="5d13cf6ebf5b56860e615c60461483284db225c521bdc8c48035daae8e33b260"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
MEDIA_DIR="${AMIGA_WALLPAPER_DIR:-$HOME/Wallpapers/Amiga}"

usage() {
  printf '%s\n' "Usage: install.sh [--uninstall]"
  printf '%s\n' "  Installs $PLUGIN_ID and the verified Amiga example pack."
  printf '%s\n' "  --uninstall removes only the plugin; user media is preserved."
}

remove_plugin() {
  export OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}"
  if [[ -d $PLUGIN_DIR ]]; then
    omarchy plugin remove "$PLUGIN_ID" --yes || true
    rm -rf "$PLUGIN_DIR"
  fi
  printf '%s\n' "Removed plugin $PLUGIN_ID. Preserved $MEDIA_DIR."
}

case "${1:-}" in
  "") ;;
  --uninstall) remove_plugin; exit 0 ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

export OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}"
command -v curl >/dev/null
command -v unzip >/dev/null
command -v sha256sum >/dev/null
command -v omarchy >/dev/null

if [[ ! -f $PLUGIN_DIR/manifest.json ]]; then
  omarchy plugin add "$REPOSITORY" --enable --yes
fi
omarchy plugin enable "$PLUGIN_ID"
omarchy-shell shell rescanPlugins

installer="$PLUGIN_DIR/bin/omarchy-amiga-install"
[[ -x $installer ]] || { printf '%s\n' "Missing plugin installer: $installer" >&2; exit 1; }
"$installer" --install-deps

mkdir -p "$MEDIA_DIR"
temporary=$(mktemp "${TMPDIR:-/tmp}/omarchy-amiga-pack.XXXXXX.zip")
trap 'rm -f "$temporary"' EXIT
curl --fail --location --retry 3 --output "$temporary" "$PACK_URL"
printf '%s  %s\n' "$PACK_SHA256" "$temporary" | sha256sum --check --status || {
  printf '%s\n' 'Amiga pack checksum verification failed.' >&2
  exit 1
}
unzip -o "$temporary" -d "$MEDIA_DIR"
"$PLUGIN_DIR/bin/omarchy-amiga-generate-fsuae" "$MEDIA_DIR" --force
"$PLUGIN_DIR/bin/omarchy-amiga-doctor"
printf '%s\n' "Installed $PLUGIN_ID with verified media in $MEDIA_DIR."
