# FHSE Profile Matrix

The current installer already contains profiles that map naturally to future FHSE targets.

## Existing installer profiles

| Profile | Expected architecture | Install mode | Future target folder |
| --- | --- | --- | --- |
| `raspberry-pi` | `aarch64` | `preinstalled-image` | `Raspberry/` |
| `mini-pc` | `x86_64` | `bootable-usb-iso` | `PC/` |
| `legacy-pc` | `x86_64` | `bootable-usb-iso` | `PC/` |
| `proxmox` | `x86_64` | `vm-template` | `VM/` |
| `x86_64-vm` | `x86_64` | `virtual-machine-test` | `VM/` |
| `arm64-vm` | `aarch64` | `virtual-machine-test` | `VM/` |
| `synology-nas` | `any` | `dsm-package` | `NAS/` later |

## Immediate conclusion

FHSE does not need a brand new conceptual model for PC and VM.

The conceptual model already exists inside the current installer:

- profile-based behavior
- architecture expectation
- deployment mode
- minimum hardware assumptions

## Practical consequence

The next implementation phase should reuse this profile logic instead of inventing a second parallel system.
