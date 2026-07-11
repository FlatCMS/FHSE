# FHSE Target Contract

Each FHSE target folder should follow the same high-level contract.

## Required structure

Every target should progressively converge toward:

- `README.md`
- `builder/` or target-specific builder root
- `releases/`
- `docs/`

## Required README sections

- supported hardware or platform
- architecture
- output artifact
- build prerequisites
- validation flow
- current status

## Required release metadata

Each released version should provide, at minimum:

- changelog
- release and test notes
- checksum file
- build log when available

## Required build guarantees

- reproducible build steps
- no interactive shell dependency in the build chain unless clearly documented
- checksum output at the end
- explicit FlatCMS payload source
- explicit security defaults

## Security defaults

Targets must not ship with:

- a publicly documented default technical password
- SSH password authentication enabled by default unless explicitly justified
- hidden mandatory exposure to the Internet

