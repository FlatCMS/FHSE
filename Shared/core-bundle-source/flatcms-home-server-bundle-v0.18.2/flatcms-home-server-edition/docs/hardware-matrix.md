# Hardware Matrix

| Device | CPU | Recommended path | Notes |
| --- | --- | --- | --- |
| Raspberry Pi 4 | ARM64 | Raspberry Pi Ubuntu preinstalled server image | USB boot may work depending on EEPROM/boot config, but microSD or SSD image is the safest customer path. |
| Raspberry Pi 400 | ARM64 | Raspberry Pi Ubuntu preinstalled server image | Same family as Raspberry Pi 4 for installer logic. |
| UTM VM on Apple Silicon | ARM64 | ARM64 VM test profile | Useful for testing installer logic before using physical hardware. |
| Generic x86_64 VM | x86_64 | VM test profile | For VirtualBox, VMware, KVM, and x86_64 UTM validation. |
| Intel NUC | x86_64 | Bootable USB ISO | Best first ISO target. BIOS/UEFI boot is standard. |
| Old Intel Celeron PC | x86_64 | Bootable USB ISO | Must check RAM, disk health, and CPU architecture. |
| Synology DS120 | ARM NAS appliance | DSM package / Web Station path | Do not treat as a normal bootable target. Use a package or manual Web Station integration. |
| Proxmox host | x86_64 | VM template or LXC template | Later target after bare metal path is stable. |

## MVP Test Order

1. Mini PC NUC.
2. Old Intel Celeron PC.
3. Generic x86_64 VM.
4. Raspberry Pi 4.
5. Synology DS120 package path.

## Why This Order

The NUC and old PC validate the bootable installer path. The generic x86_64 VM validates the same server stack in a faster disposable environment. Raspberry validates the ARM image path. Synology is a different distribution model and should be isolated from the USB/ISO workflow.
