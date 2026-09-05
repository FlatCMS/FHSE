# FHSE

FHSE is the **FlatCMS Home Server Edition** project.

This repository hosts the platform-specific builders, deployment assets, and shared contracts used to deliver FlatCMS as a turnkey self-hosted appliance without requiring command-line operations from the final user.

## Current layout

- `images/`
  - local binary drop zone for generated FHSE images
  - centralizes future `.img`, `.img.xz`, `.iso`, `.qcow2`, `.ova`
  - intentionally excluded from Git
- `Raspberry/`
  - active Raspberry Pi 4 / 400 appliance builder
  - Linux-only build pipeline for the bootable Raspberry image
- `PC/`
  - experimental x86_64 installer target
  - ISO-oriented deployment flow for mini PCs, NUCs, and legacy PCs
- `VM/`
  - active virtual appliance target
  - ARM64 installer ISO for UTM plus future VM artifacts
- `docs/`
  - shared architecture and target contracts

## Repository policy

- keep source, scripts, and useful docs in Git
- do not commit generated disk images such as `.img`, `.img.xz`, `.iso`, `.qcow2`, or `.ova`
- keep generated binaries in `images/` locally or publish them later as GitHub release assets

## Current tracked target

The current validated target families are:

- Raspberry Pi 4 / 400
- ARM64 VM ISO for UTM

## Release payload workflow

Stage a validated, versioned FlatCMS archive before building either image:

```bash
Shared/tools/stage-flatcms-release-payload.sh /path/to/flatcms-1.1.7.zip 1.1.7
```

The public artifact name always includes both the FHSE release and the
embedded FlatCMS version. The internal appliance payload remains named
`flatcms.zip` because the unattended installer depends on that stable name.

## Next target families

Planned next target families:

- `PC/`
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
