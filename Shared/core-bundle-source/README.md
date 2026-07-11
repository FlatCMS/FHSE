# FHSE Shared Core Bundle Source

This folder contains the neutral FHSE runtime source extracted from the validated Raspberry target.

## Includes

- installer runtime
- wizard preview runtime
- profile definitions
- docs
- examples

## Excludes

The FlatCMS application payload is intentionally not duplicated here:

- `packages/flatcms.zip`

That payload remains embedded in target builders and should be injected from the official FlatCMS package during target build or target refresh workflows.

