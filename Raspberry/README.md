# Raspberry

This folder contains the Raspberry Pi target for FHSE.

## Contents

- `rpi4-appliance-builder/`
  - working builder source and boot overlay used to generate the Raspberry Pi appliance image
- `releases/`
  - lightweight release metadata kept in Git
  - changelog
  - test notes
  - checksum
  - build log

## Intentionally excluded from Git

Generated release binaries are not tracked in this repository:

- `.img`
- `.img.xz`

Those files should be stored locally or published later as release assets.

## Current tracked Raspberry target

- Raspberry Pi 4
- Raspberry Pi 400
- Ubuntu Server ARM64 base image

