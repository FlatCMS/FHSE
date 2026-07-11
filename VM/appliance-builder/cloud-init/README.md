# VM Cloud-Init Seed

This folder will host the cloud-init seed used by the FHSE VM target.

## Intent

The VM flow should eventually:

- boot from a prepared base image
- receive initial runtime configuration through cloud-init
- stage the FHSE shared bundle
- continue with the FHSE onboarding/runtime flow

## Planned files

- `meta-data`
- `user-data.template`
- optional generated `user-data` during build

## Rule

Do not hardcode secrets in Git.

