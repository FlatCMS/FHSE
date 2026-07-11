# FHSE PC x86_64 ISO Builder

## Objective

Produce a bootable FHSE installer ISO for x86_64 hardware.

## Expected output

- `fhse-pc-vX.Y.Z-x86_64.iso`

## Build responsibilities

- fetch or reference the Ubuntu Server x86_64 base media
- inject FHSE installer assets
- configure the unattended or semi-guided installation flow
- install aaPanel, Nginx, PHP, and FlatCMS
- preserve the FHSE no-terminal promise for the final user

## Source inputs that will likely be shared with Raspberry

- wizard UI concepts
- FlatCMS payload policy
- installation steps
- security defaults
- release checklist

## Initial milestone

The first milestone for this builder should be a documented skeleton with:

- base ISO strategy
- autoinstall strategy
- storage layout assumptions
- release output naming

