# VM

This folder will host the FHSE target for virtualized environments.

## Target scope

- Proxmox
- KVM / QEMU
- VirtualBox
- VMware
- UTM

## Planned primary artifacts

- `.iso` for UTM and fresh VM installation
- `.qcow2` later
- `.ova` later

## Product intent

The VM target is meant for users who want to deploy FHSE quickly inside an already available virtualization platform.

## Status

In progress.

Current active target:

- ARM64 installer ISO for UTM `Virtualize`

Current local artifact target:

- `images/VM/fhse-vm-v0.18.2-arm64-rc3.13-1.1.6.iso`

The active VM builder currently lives in:

- `VM/appliance-builder/`

The x86_64 installer-oriented builder remains available separately in:

- `PC/x86_64-iso-builder/`
