# FHSE v0.18.2 RC3.10 Mini Changelog

## Scope

This release candidate packages **FHSE FlatCMS Home Server Edition** for Raspberry Pi 4 / 400 with:

- Ubuntu Server base image
- aaPanel
- Nginx
- PHP 8.5 with required extensions
- FlatCMS deployed in the default aaPanel web root
- local wizard available on the LAN

## Main changes in this RC

### Security and access

- removed the previous `admin/admin` bootstrap pattern
- technical Ubuntu access is now initialized in a **locked state** until configured by the wizard
- SSH password authentication is **disabled by default**
- the wizard now clearly separates:
  - FHSE web setup
  - optional Cloudflare Tunnel exposure
  - technical Ubuntu access

### Product packaging

- embedded `flatcms.zip` replaced with the final official FlatCMS release package
- builder bundle rebuilt cleanly with the updated FlatCMS payload
- version labels aligned to `v0.18.2 RC3.10`

### Wizard

- clarified the onboarding flow for non-technical users
- added explicit technical password setup and confirmation
- Cloudflare Tunnel remains **optional** with clearer messaging
- final summary screen no longer exposes the technical password back to the user

### Build and validation

- appliance image rebuilt successfully on Ubuntu ARM
- root filesystem patching validated
- FHSE bundle extraction validated
- release image compressed successfully and checksummed

## Final artifacts

- `fhse-rpi4-v0.18.2-rpi4.1-rc3.10.img`
- `fhse-rpi4-v0.18.2-rpi4.1-rc3.10.img.xz`
- `fhse-rpi4-v0.18.2-rpi4.1-rc3.10.img.sha256`
- `fhse-rpi4-appliance-builder-v0.18.2-rc3.10-patched.zip`

## Checksums

- `fhse-rpi4-v0.18.2-rpi4.1-rc3.10.img`
  - `aaedbbe83b4f71c0955c2bda43e610c53b12ed44f194eb6b97e8bfa289563e7b`
- `fhse-rpi4-v0.18.2-rpi4.1-rc3.10.img.xz`
  - `89d8bc22ae91c908ee833b5e7e7cb49f8f68ae284525cb7248bdcfe932b7082b`
- `fhse-rpi4-appliance-builder-v0.18.2-rc3.10-patched.zip`
  - `1c39c8ca7e8261bef1bd3e926addcb488c11ab4eaea3ac49a17f15e9fc4e5c43`

