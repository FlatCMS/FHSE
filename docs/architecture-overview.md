# FHSE Architecture Overview

## Goal

FHSE must deploy FlatCMS on supported hardware or virtual targets without requiring command-line work from the final user.

## Product split

FHSE is split into two layers:

### 1. Shared FHSE core

This layer contains:

- the product documentation
- the onboarding concepts
- the deployment contracts
- the wizard UI direction
- the installation step model
- the FlatCMS payload policy
- the release and validation rules

### 2. Target-specific runtimes

Each target owns its own builder and packaging logic:

- `Raspberry/`
- `PC/`
- `VM/`

Later:

- `NAS/`

## Target policy

Each target should expose:

- one documented input platform
- one primary release artifact
- one repeatable build flow
- one validation checklist
- one release metadata folder

## Primary artifact by target

- Raspberry:
  - `.img.xz`
- PC:
  - `.iso`
- VM:
  - `.qcow2` and/or `.ova`

## Shared functional expectations

Every target should converge toward the same user-facing outcome:

- Ubuntu-based host runtime
- aaPanel
- Nginx
- PHP with required extensions
- FlatCMS deployed automatically
- local onboarding wizard
- optional Cloudflare Tunnel
- no default technical password exposed

## Release policy

Keep in Git:

- source
- scripts
- documentation
- checksums
- logs
- release notes

Do not keep in Git:

- generated disk images
- generated ISO files
- generated VM appliance binaries

