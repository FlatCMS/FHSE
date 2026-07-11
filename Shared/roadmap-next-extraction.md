# FHSE Shared Extraction Roadmap

## Objective

Turn the current Raspberry-first bundle into a neutral reusable FHSE core without destabilizing the validated Raspberry delivery.

## Phase 1

Keep the Raspberry builder as the physical canonical implementation and document the shared/runtime split.

Status:

- done

## Phase 2

Extract the logical common runtime into a neutral folder:

- `Shared/core-bundle-source/`

Status:

- done

This neutral source now includes:

- wizard runtime
- installer runtime
- profile files
- product docs
- examples

And intentionally excludes:

- the heavy `packages/flatcms.zip` payload

## Phase 3

Make target builders consume the shared runtime instead of hosting independent copies.

Example:

- `Raspberry/` consumes the shared core and adds image-specific wrapping
- `PC/` consumes the shared core and adds ISO-specific wrapping
- `VM/` consumes the shared core and adds VM packaging-specific wrapping

## Phase 4

Add automated validation to detect drift between:

- the shared core
- Raspberry target embedding
- future PC target embedding
- future VM target embedding
