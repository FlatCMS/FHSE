# Shared

This folder documents and progressively hosts the FHSE logic that should be reused by all targets.

## Current state

At this stage, the canonical implementation of the shared FHSE logic is now duplicated in a neutral source folder for extraction work:

- `Shared/core-bundle-source/flatcms-home-server-bundle-v0.18.2/`

The validated Raspberry embedding remains here:

- `Raspberry/rpi4-appliance-builder/bundle-src/flatcms-home-server-bundle-v0.18.2/`

That source already contains:

- the installer runtime
- the wizard preview
- the profile system
- the FlatCMS deployment flow
- the product documentation
- but not the embedded `packages/flatcms.zip` payload

## Why this folder exists now

The repository is moving from a Raspberry-first proof of concept toward a true multi-target product.

Before moving files physically, we first define:

- what belongs to the shared core
- what remains target-specific
- which existing profiles already map to future targets

## Current rule

The shared source is intentionally kept lightweight:

- source files are tracked in `Shared/core-bundle-source/`
- the heavy `flatcms.zip` payload stays in the target builders

## Next step

The next step is to make target builders consume this shared source through explicit synchronization or packaging scripts without breaking the working Raspberry target.
