# FHSE PC x86_64 ISO Builder

## Objective

Produce a bootable FHSE installer ISO for x86_64 hardware.

## Current output

The builder now targets this artifact:

- `images/VM/fhse-vm-v0.18.2-x86_64-rc3.12.iso`

## Current strategy

The ISO builder uses:

- Ubuntu Server 22.04.5 amd64 live ISO as the base media
- a seeded `autoinstall` configuration injected into the ISO
- the shared FHSE bundle archive copied into `/fhse/` on the ISO
- a target-side helper that installs the locked technical account, the FHSE wizard service, and the shared bundle inside the installed system

At the end of the Ubuntu installation, the target boots as an FHSE appliance and exposes:

- `http://fhse.local:8080`
- `http://fhse.local:8080/server/`

## Build flow

1. prepare the shared FHSE core bundle
2. render `autoinstall/user-data` from the local `.env`
3. extract the official Ubuntu ISO into a writable workspace
4. inject:
   - `autoinstall/user-data`
   - `autoinstall/meta-data`
   - `fhse/install-fhse-target.sh`
   - `fhse/flatcms-home-server-bundle-v0.18.2-no-builders.zip`
5. patch the GRUB/ISOLINUX boot entries with:
   - `autoinstall ds=nocloud;s=/cdrom/autoinstall/`
6. rebuild a bootable ISO

The Ubuntu base ISO cache stays local to:

- `PC/x86_64-iso-builder/dist/`

The final FHSE VM-ready installer ISO is written to:

- `images/VM/`

## Builder commands

- Prepare the shared bundle:
  - `tools/prepare-fhse-core-bundle.sh`
- Render the autoinstall seed:
  - `tools/render-autoinstall-user-data.sh`
- Stage the local workspace:
  - `tools/stage-workspace.sh`
- Build the final ISO:
  - `tools/build-fhse-pc-x86_64-iso.sh --download`

## Supported builder hosts

The final ISO build currently supports:

- Linux with `xorriso`
- macOS with `xorriso`

Recommended hosts:

- Ubuntu / Debian
- macOS + UTM workflow

## macOS prerequisite

On macOS, install `xorriso` first:

- `brew install xorriso`

## Local config

Default sample config:

- `examples/fhse-pc.env.example`

Expected key values:

- `FHSE_OS_HOSTNAME`
- `FHSE_OS_USERNAME`
- `FHSE_OS_PASSWORD`
