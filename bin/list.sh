#!/usr/bin/env bash
set -euo pipefail

ROOTS=("${AMIGA_WALLPAPER_DIR:-$HOME/Wallpapers/Amiga}" "$HOME/.config/omarchy/amiga")
for root in "${ROOTS[@]}"; do
  [[ -d "$root" ]] || continue
  while IFS= read -r -d '' file; do
    printf '%s\n' "$file"
  done < <(find "$root" -type f \( -iname '*.dms' -o -iname '*.adf' \) -print0 2>/dev/null | sort -z)
done
