# FHSE

FHSE is the **FlatCMS Home Server Edition** project.

This repository is intended to host the platform-specific builders, deployment assets, and release notes used to deliver FlatCMS as a turnkey self-hosted appliance without requiring command-line operations from the final user.

## Current layout

- `Raspberry/`
  - first tracked target
  - Raspberry Pi 4 / 400 appliance builder
  - release notes and checksums for the latest validated Raspberry image

## Repository policy

- keep source, scripts, docs, and small traceability artifacts in Git
- do not commit generated disk images such as `.img`, `.img.xz`, `.iso`, `.qcow2`, or `.ova`
- keep release binaries outside Git or publish them as GitHub release assets later

## Current tracked target

The first committed target is:

- Raspberry Pi 4 / 400
- Ubuntu Server based appliance
- aaPanel
- Nginx
- PHP 8.5
- FlatCMS bundled in the default website root

## Next target families

Planned future folders:

- `PC/`
- `VM/`
- `NAS/`

