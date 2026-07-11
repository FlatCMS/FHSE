# FHSE Core Bundle Contract

## Current canonical source

The current neutral source of the FHSE core runtime is:

- `Shared/core-bundle-source/flatcms-home-server-bundle-v0.18.2/`

The current validated embedded target copy remains:

- `Raspberry/rpi4-appliance-builder/bundle-src/flatcms-home-server-bundle-v0.18.2/`

## What belongs to the shared core

These parts are target-agnostic and should eventually become the common FHSE runtime:

- `start-wizard-preview.sh`
- `wizard-preview/`
- `flatcms-home-server-edition/installer/`
- `flatcms-home-server-edition/examples/`
- `flatcms-home-server-edition/docs/`

## What is target-specific

These parts are target wrappers and should remain per target:

- Raspberry disk image build scripts
- boot overlay files
- cloud-init boot seed files
- target-specific ISO generation logic
- target-specific VM packaging logic

## FlatCMS payload rule

The FlatCMS application payload is shared across targets, but the embedding method can differ:

- Raspberry:
  - bundled into the boot overlay archive
- PC:
  - embedded into the installer ISO workflow or fetched during build
- VM:
  - embedded into the appliance image workflow or provisioned during first boot

## Extraction rule

Until all target builders consume the shared source automatically, the Raspberry target should be treated as:

- the validated embedded runtime
- synchronized from the neutral shared source

This avoids breaking the validated target while making future PC and VM work converge on one source.
