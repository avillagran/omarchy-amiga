# Omarchy Amiga Screensaver

Native Amiga demo screensaver for Omarchy, powered exclusively by FS-UAE.

The installer supports `x86_64` and `aarch64`, integrates with Omarchy's idle service and screensaver menu, and installs the current prepared demo pack automatically.

## Install

Run:

```bash
curl -fsSL https://raw.githubusercontent.com/avillagran/omarchy-amiga/native-v0.4.4/install.sh | bash
```

The installer is safe to run again when upgrading or repairing an installation.

## What is installed

- Architecture-specific native runtime in `~/.local/lib/omarchy-amiga-runtime`
- FS-UAE launcher, selector, and runtime checker in `~/.local/bin`
- Native Omarchy idle-service integration and screensaver menu entries
- The current prepared pack of 31 demos in `~/Wallpapers/AMIGA`

The pack includes checksum-bound configurations, media, previews, and saved states required for immediate playback. The runtime uses FS-UAE as its only emulator backend.

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
curl -fsSL https://raw.githubusercontent.com/avillagran/omarchy-amiga/native-v0.4.4/install.sh | bash -s -- --uninstall
```

Uninstalling removes the managed runtime, launchers, menu integration, and plugin files while preserving `~/Wallpapers/AMIGA` and other user media.

## Release

The current tested release is [`native-v0.4.4`](https://github.com/avillagran/omarchy-amiga/releases/tag/native-v0.4.4).

The runtime archives are unchanged from `native-v0.4.2`, which was installed and visually verified on x86_64 Omarchy hardware and tested in an x86_64 Omarchy QEMU guest. This release downloads a checksum-bound 24-production pack generated from explicit review decisions: 9 productions have manually selected end times, 7 of those also have manually selected start states, and 7 discarded productions are excluded. Verified v0.2 and v0.3 packs upgrade safely; unrecognized user-managed packs are preserved.

## Media and ROMs

This project does not distribute proprietary Kickstart ROMs. Demo media is packaged separately from the Git repository and installed from the pinned release asset used by the installer.

## Author

Andrés Villagrán <andres@villagranquiroz.cl>
