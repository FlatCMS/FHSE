# PC Builder Assets

This folder contains the small assets used by the x86_64 ISO builder:

- generated FHSE bundle archive:
  - `flatcms-home-server-bundle-v0.18.2-no-builders.zip`
- target-side helper copied into the ISO:
  - `install-fhse-target.sh`

The generated bundle archive stays lightweight enough for local staging, but the final bootable ISO itself is not committed to Git.
