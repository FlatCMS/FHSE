# FHSE VM Appliance Builder

## Objective

Produce ready-to-import FHSE virtual appliances.

## Expected outputs

- `fhse-vm-vX.Y.Z-x86_64.qcow2`
- `fhse-vm-vX.Y.Z-x86_64.ova`

## Intended strategy

The VM target should reuse the shared FHSE installation logic while packaging it for virtualization-first workflows.

## First supported runtime candidates

- Proxmox / KVM with `qcow2`
- desktop virtualization import with `ova`

## Validation expectations

- appliance boots without manual repair
- onboarding wizard is reachable on the LAN
- aaPanel installs correctly
- FlatCMS is available at the end of the workflow

## Current helper

This target can already prepare the shared FHSE bundle archive through:

- `tools/prepare-fhse-core-bundle.sh`

It can also stage the first local VM workspace skeleton through:

- `tools/stage-workspace.sh`
