# Omarchy Amiga Demo Backgrounds

Standalone Omarchy service for loading legal Amiga disk images through Amiberry,
with FS-UAE as a fallback.

Amiberry upstream: https://github.com/BlitterStudio/amiberry

The plugin includes the Amiberry runtime and selects it automatically. It does
not require `yay`, `pacman`, a compiler, or a separate emulator installation.
Intel and AMD 64-bit systems use the same `x86_64` binary; ARM64 systems use
`aarch64`. Each binary must be built against the Omarchy/Arch runtime; foreign
Ubuntu/Fedora packages are not substituted with ABI symlinks.

Supported input:

- `.dms`
- `.adf`

The disk image is not modified. A Kickstart ROM, when required by a demo, must
be supplied legally by the user in the normal Kickstart location shared with FS-UAE/Amiberry:

```text
~/Documents/FS-UAE/Kickstarts/
```

## Install locally

From this directory:

```bash
omarchy plugin install .
omarchy plugin enable io.github.avillagran.omarchy-amiga
```

Put demos in:

```text
~/Wallpapers/Amiga/
```

List available demos:

```bash
bin/list.sh
```

## Run directly

This launches Amiberry fullscreen when installed and preserves the original
demo timing and rendering:

```bash
bin/omarchy-amiga start ~/Wallpapers/Amiga/demo.dms direct
```

Stop it with:

```bash
bin/omarchy-amiga stop
```

The same operation through the service IPC is:

```bash
omarchy-shell -q io.github.avillagran.omarchy-amiga start /absolute/path/demo.dms direct
omarchy-shell -q io.github.avillagran.omarchy-amiga stop
```

## Background mode

`background` launches Amiberry inside a real `gtk4-layer-shell` background
surface. On ARM64 the plugin uses its bundled preload; on x86_64 it references
the native `/usr/lib/liblayer-shell-preload.so` supplied by Omarchy and uses
the architecture-matched SDL shim. The demo remains an unmodified original
disk image and continues to render through Amiberry. FS-UAE is used only when
Amiberry is not installed.

The active surface can be verified with:

```bash
hyprctl layers
```

Look for `namespace: omarchy-amiga` under `Layer level 0 (background)`. The
launcher records the emulator result in the legacy state/log path:

```text
~/.local/state/omarchy/amiga/fs-uae.log

## Amiberry runtime and license

The bundled runtime is Amiberry 8.3.0, licensed under GPLv3. Its license is in
`bin/amiberry/LICENSE`. The corresponding upstream source is available at:

https://github.com/BlitterStudio/amiberry/tree/v8.3.0

Kickstart ROMs and demo disk images are not bundled by this plugin.
```
