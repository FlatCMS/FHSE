# PC Autoinstall Seed

This folder will host the Ubuntu autoinstall seed used by the FHSE PC target.

## Intent

The x86_64 ISO flow should eventually:

- boot on dedicated PC hardware
- launch a controlled Ubuntu installation
- stage the FHSE shared bundle
- continue with the FHSE onboarding/runtime flow

## Planned files

- `meta-data`
- `user-data.template`
- optional generated `user-data` during build

## Rule

Do not hardcode secrets in Git.

