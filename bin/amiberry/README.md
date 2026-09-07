# Bundled Amiberry runtime

This directory contains the upstream Amiberry 8.3.0 runtime for Linux ARM64
and x86_64. The launcher selects the directory matching `uname -m`.

Amiberry is GPLv3 software:

- Upstream: https://github.com/BlitterStudio/amiberry
- Source tag: `v8.3.0`
- License: `LICENSE`

The runtimes are built for the Linux libraries supplied by Omarchy. Do not
replace SONAMEs with symlinks between distributions; rebuild for the target
Omarchy architecture instead.