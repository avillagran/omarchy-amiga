# Omarchy Amiga Demo Backgrounds

Standalone Omarchy service for loading legal Amiga disk images through FS-UAE.

FS-UAE is the only emulator backend. The plugin does not bundle or invoke
another emulator and requires the system `fs-uae` package.

Supported input:

- `.dms`
- `.adf`

The disk image is not modified. A Kickstart ROM, when required by a demo, must
be supplied legally by the user in the normal FS-UAE Kickstart location:

```text
~/Documents/FS-UAE/Kickstarts/
```

Kickstart ROMs are never downloaded by this plugin. A legal Kickstart is needed
for reliable compatibility with original productions.

## Install

Install the plugin, enable it, install FS-UAE dependencies, and download the verified example pack with one command:

```bash
curl -fsSL https://raw.githubusercontent.com/avillagran/omarchy-amiga/AMIGATESTS/install.sh | bash
```

The installer verifies the release asset before extracting it into `~/Wallpapers/Amiga`; it never downloads Kickstart ROMs. Re-running it is safe and preserves existing user media.

Remove the plugin while preserving downloaded demos, configurations, previews, and user-supplied ROMs:

```bash
curl -fsSL https://raw.githubusercontent.com/avillagran/omarchy-amiga/AMIGATESTS/install.sh | bash -s -- --uninstall
```

To inspect the installer before running it:

```bash
curl -fsSL https://raw.githubusercontent.com/avillagran/omarchy-amiga/AMIGATESTS/install.sh
```

The installer installs FS-UAE and its runtime libraries through `pacman`, creates
the user media/Kickstart directories, and checks the system binary with `ldd`
and `--version`. It never downloads ROMs or disk images. Use `--check` to skip
package installation.

To inspect a broken installation without changing anything:

```bash
~/.config/omarchy/plugins/io.github.avillagran.omarchy-amiga/bin/omarchy-amiga-doctor
```

Generate one FS-UAE configuration per demo folder. The files stay beside the
user-owned disk images and are not part of the repository:

```bash
~/.config/omarchy/plugins/io.github.avillagran.omarchy-amiga/bin/omarchy-amiga-generate-fsuae
```

The generated configuration uses FS-UAE's internal AROS ROM, conservative
A500/ECS defaults, and lists every disk in a multi-disk folder. Names containing
`AGA`, `A1200`, or `CD32` select A1200/AGA. The launcher loads `omarchy.fs-uae`
automatically when it is present.

## Demo pack v0.1

The demo media is distributed separately from Git. Download
`omarchy-amiga-demos-v0.1.zip`, then install it with:

```bash
mkdir -p ~/Wallpapers/Amiga
unzip -o omarchy-amiga-demos-v0.1.zip -d ~/Wallpapers/Amiga
~/.config/omarchy/plugins/io.github.avillagran.omarchy-amiga/bin/omarchy-amiga-generate-fsuae \
  ~/Wallpapers/Amiga --force
```

Install FS-UAE and the plugin first if needed:

```bash
omarchy plugin add https://github.com/avillagran/omarchy-amiga --enable --yes
~/.config/omarchy/plugins/io.github.avillagran.omarchy-amiga/bin/omarchy-amiga-install --install-deps
```

The pack contains user-owned demo media only. It contains no Kickstart ROMs.
FS-UAE uses its internal AROS ROM by default; legal user-supplied Kickstarts,
when needed for a production, belong in `~/Documents/FS-UAE/Kickstarts/`.

Put demos in:

```text
~/Wallpapers/Amiga/
```

List available demos:

```bash
bin/list.sh
```

## Run directly

This launches FS-UAE fullscreen when installed and preserves the original
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

`background` launches FS-UAE inside a real `gtk4-layer-shell` background
surface. The demo remains an unmodified original disk image.

The active surface can be verified with:

```bash
hyprctl layers
```

Look for `namespace: omarchy-amiga` under `Layer level 0 (background)`. The
launcher records the emulator result in the legacy state/log path:

```text
~/.local/state/omarchy/amiga/fs-uae.log
```

Kickstart ROMs and demo disk images are not bundled by this plugin.
