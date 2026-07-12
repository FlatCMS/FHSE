# FHSE

FHSE is the **FlatCMS Home Server Edition** project.

This repository is intended to host the platform-specific builders, deployment assets, and release notes used to deliver FlatCMS as a turnkey self-hosted appliance without requiring command-line operations from the final user.

## Current layout

- `images/`
  - local binary drop zone for generated FHSE images
  - centralizes future `.img`, `.img.xz`, `.iso`, `.qcow2`, `.ova`
  - intentionally excluded from Git
- `Raspberry/`
  - first tracked target
  - Raspberry Pi 4 / 400 appliance builder
  - release notes and checksums for the latest validated Raspberry image
- `PC/`
  - future x86_64 installer target
  - ISO-oriented deployment flow for mini PCs, NUCs, and legacy PCs
- `VM/`
  - future virtual appliance target
  - VM-oriented outputs such as qcow2, ova, and preconfigured appliances
- `docs/`
  - shared architecture and target contracts

## Repository policy

- keep source, scripts, docs, and small traceability artifacts in Git
- do not commit generated disk images such as `.img`, `.img.xz`, `.iso`, `.qcow2`, or `.ova`
- keep generated binaries in `images/` locally or publish them later as GitHub release assets

## Current tracked target

The first committed target is:

- Raspberry Pi 4 / 400
- Ubuntu Server based appliance
- aaPanel
- Nginx
- PHP 8.5
- FlatCMS bundled in the default website root

## Next target families

Planned target families:

- `PC/`
- `VM/`
- `NAS/`

## Product direction

FHSE is evolving toward a multi-target deployment platform able to deliver FlatCMS with the same no-terminal user promise across:

- Raspberry Pi
- mini PCs / NUCs
- legacy PCs
- virtual machines
- existing Linux servers
- NAS platforms later

The repository therefore keeps one shared product direction while splitting platform-specific builders per target.
