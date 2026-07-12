# PC ISO Builder Implementation Plan

## Current implemented baseline

The x86_64 target now has a first usable baseline:

1. Ubuntu Server 22.04.5 amd64 base ISO workflow
2. injected `autoinstall` seed inside the ISO itself
3. shared FHSE bundle staged into `/fhse/`
4. target-side helper that installs:
   - the locked `admin` technical account
   - the FHSE wizard service on port `8080`
   - the shared bundle in `/opt/flatcms-home-server`
5. hostname normalization to `fhse.local` by default

## Remaining validation work

1. build the first ISO on a supported host with `xorriso`
2. boot a brand new x86_64 VM from this ISO
3. confirm unattended Ubuntu install completes without manual repair
4. confirm the first boot exposes:
   - `http://fhse.local:8080`
   - `http://fhse.local:8080/server/`
5. confirm the web wizard can then install:
   - aaPanel
   - Nginx
   - PHP 8.5
   - FlatCMS

## Next hardening steps

1. add release metadata and checksum output for the final ISO
2. verify BIOS + UEFI boot parity
3. validate UTM / VirtualBox / Proxmox import expectations
4. confirm the macOS builder path stays first-class for local UTM testing
