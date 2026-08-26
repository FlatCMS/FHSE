# FHSE Local Images

This folder centralizes locally generated FHSE release binaries across targets.

Examples:

- `images/Raspberry/`
- `images/VM/`
- `images/PC/`

Published artifact names include both the FHSE version and the embedded
FlatCMS version, for example:

- `fhse-rpi4-v0.18.2-rpi4.1-rc3.13-1.1.6.img.xz`
- `fhse-vm-v0.18.2-arm64-rc3.13-1.1.6.iso`

Repository policy:

- generated binaries are intentionally excluded from Git
- only validated local artifacts should remain in this folder
