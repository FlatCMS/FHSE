# VM Appliance Builder Implementation Plan

## Immediate objective

Use the shared FHSE core bundle as the application/runtime payload for future VM appliance builds.

## Planned next implementation steps

1. choose the first canonical VM output between `qcow2` and `ova`
2. define the base image preparation path
3. stage the shared FHSE bundle into the VM build workspace
4. define first-boot or preinstalled provisioning behavior
5. define validation on Proxmox and a desktop virtualization runtime

