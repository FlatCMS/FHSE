# PC

This folder will host the FHSE target for x86_64 physical machines.

## Validation status

Experimental and not yet validated.

No PC installer image is currently considered field-tested or release-ready.

## Target scope

- mini PCs
- NUC-like hardware
- legacy PCs dedicated to FHSE
- bare-metal x86_64 installations

## Planned primary artifact

- `.iso`

## Product intent

The PC target is meant for users who want to install FHSE on a dedicated machine without first preparing Linux manually.

## Current direction

The first PC target should be based on:

- Ubuntu Server x86_64
- unattended or guided autoinstall flow
- automatic installation of aaPanel, Nginx, PHP, and FlatCMS
- the same FHSE onboarding logic used by the Raspberry target

## Status

A first PC builder exists in this repository, but the generated PC artifacts are
still untested and must be treated as experimental.
