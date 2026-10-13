# Omarchy Amiga Screensaver

Native Amiga demo screensaver for Omarchy, powered exclusively by FS-UAE.

The installer supports `x86_64` and `aarch64`, integrates with Omarchy's idle service and screensaver menu, and installs the current prepared demo pack automatically.

## Install

Run:

```bash
curl -fsSL https://raw.githubusercontent.com/avillagran/omarchy-amiga/native-v0.5.0/install.sh | bash
```

The installer is safe to run again when upgrading or repairing an installation.

## What is installed

- Architecture-specific native runtime in `~/.local/lib/omarchy-amiga-runtime`
- FS-UAE launcher, selector, and runtime checker in `~/.local/bin`
- Native Omarchy idle-service integration and screensaver menu entries
- The curated selection ZIP tracked in `selection/amiga-screensaver-selection.zip`
- The current prepared selection of 13 demos in `~/Wallpapers/AMIGA`

The selection includes checksum-bound configurations, media, previews, and a saved state for every demo. Playback starts from those states instead of replaying each production's boot/loading sequence. The runtime uses FS-UAE as its only emulator backend.

If `~/Wallpapers/AMIGA/SHA256SUMS` already exists, the installer preserves the pack and verifies it in place instead of downloading it again. It never modifies the separate legacy directory `~/Wallpapers/Amiga`.

## Use

Select the native screensaver from:

```text
Style > Screensaver > Amiga
```

Start a preview from:

```text
Style > Screensaver > Preview
```

You can also run the installed preview launcher directly:

```bash
~/.local/bin/omarchy-launch-screensaver force
```

The screensaver starts muted. During playback:

- `M` toggles audio without closing the screensaver.
- Left and Right navigate through the demo history.
- Other intentional input dismisses the screensaver.

## Verify

Check the installed runtime, pack, and live Omarchy integration:

```bash
~/.local/bin/omarchy-screensaver-amiga --check
```

A successful check exits silently with status 0.

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/avillagran/omarchy-amiga/native-v0.5.0/install.sh | bash -s -- --uninstall
```

Uninstalling removes the managed runtime, launchers, menu integration, and plugin files while preserving `~/Wallpapers/AMIGA` and other user media.

## Release

The current tested release is [`native-v0.5.0`](https://github.com/avillagran/omarchy-amiga/releases/tag/native-v0.5.0).

The native runtime and plugin assets remain pinned to the verified `native-v0.4.5` release. This release moves the calibrated selection into this repository as a checksum-bound ZIP and makes the installer download it automatically. The selection contains the 13 productions kept during review, each with a saved state for a clean playback start. Verified v0.2, v0.3, and v0.4 packs upgrade safely; unrecognized user-managed packs are preserved.

## Media and ROMs

This project does not distribute proprietary Kickstart ROMs. Demo media is packaged separately from the Git repository and installed from the pinned release asset used by the installer.

## Author

Andrés Villagrán <andres@villagranquiroz.cl>
