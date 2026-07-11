# Shared

This folder documents and progressively hosts the FHSE logic that should be reused by all targets.

## Current state

At this stage, the canonical implementation of the shared FHSE logic still lives inside the Raspberry builder source:

- `Raspberry/rpi4-appliance-builder/bundle-src/flatcms-home-server-bundle-v0.18.2/`

That bundle already contains:

- the installer runtime
- the wizard preview
- the profile system
- the FlatCMS deployment flow
- the product documentation

## Why this folder exists now

The repository is moving from a Raspberry-first proof of concept toward a true multi-target product.

Before moving files physically, we first define:

- what belongs to the shared core
- what remains target-specific
- which existing profiles already map to future targets

## Next step

Once the structure is validated, the shared runtime can be extracted from the Raspberry builder into a neutral common bundle without breaking the working target.

