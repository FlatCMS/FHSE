# VM Appliance Builder Implementation Plan

## Current implemented direction

The first reliable VM target is now:

1. ARM64 Ubuntu Server installer ISO
2. optimized for UTM `Virtualize` on Apple Silicon
3. shared FHSE bundle embedded inside the ISO
4. target-side helper that installs:
   - the locked `admin` technical account
   - the FHSE wizard service on port `8080`
   - the shared bundle in `/opt/flatcms-home-server`
5. hostname normalization to `fhse.local` by default

## Remaining validation work

1. build the first ARM64 VM ISO locally
2. boot a brand new ARM64 UTM VM from this ISO
3. confirm unattended Ubuntu install completes without manual repair
4. confirm the first boot exposes:
   - `http://fhse.local:8080`
   - `http://fhse.local:8080/server/`
5. confirm the web wizard can then install:
   - aaPanel
   - Nginx
   - PHP 8.5
   - FlatCMS

## Later hardening steps

1. add `qcow2` output for Proxmox and generic KVM
2. add `ova` export only after the ARM64 ISO flow is stable
3. keep the VM target aligned with the shared FHSE runtime contract
