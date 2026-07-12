# Package Payload Policy

The shared FHSE core source does not duplicate the FlatCMS payload archive.

## Expected payload

- file: `packages/flatcms.zip`
- current validated SHA-256:
  - `b0cf4d9cf1e9e6805ce0293989248a6d16be9c7fc2f309872beca103b4cb8ba0`

## Rationale

Keeping the payload out of the shared source avoids unnecessary repository growth while preserving a single neutral runtime source for:

- Raspberry
- PC
- VM

## Target rule

Each target builder is responsible for embedding the payload at packaging time or refresh time.
