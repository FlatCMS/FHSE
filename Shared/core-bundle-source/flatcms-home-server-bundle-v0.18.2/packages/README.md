# Package Payload Policy

The shared FHSE core source does not duplicate the FlatCMS payload archive.

## Expected payload

- file: `packages/flatcms.zip`
- current validated SHA-256:
  - `78617f2df4f5a9599b0651eee0af1854113ec89acd1dd33df5bae93388717690`

## Rationale

Keeping the payload out of the shared source avoids unnecessary repository growth while preserving a single neutral runtime source for:

- Raspberry
- PC
- VM

## Target rule

Each target builder is responsible for embedding the payload at packaging time or refresh time.

