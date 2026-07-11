# MVP Roadmap

## Phase 0 - Design and Installer Skeleton

- Define hardware profiles.
- Define installer configuration.
- Create modular shell steps.
- Create healthcheck and repair conventions.
- Create final UI mockup.

## Phase 1 - Existing Ubuntu Install Test

Goal: run the installer on an already installed Ubuntu 22.04 machine over SSH or local terminal.

- Validate OS and architecture.
- Install system packages.
- Install aaPanel.
- Install stack placeholder.
- Generate final report.

## Phase 2 - Mini PC USB Installer

Goal: create an amd64 bootable installer workflow.

- Build Ubuntu autoinstall config.
- Add first boot wizard.
- Run the installer on the NUC.
- Repeat on the Celeron PC.

## Phase 3 - Raspberry Pi Image

Goal: create a Raspberry Pi compatible image workflow.

- Start from Ubuntu Server preinstalled arm64 image.
- Add first boot service.
- Regenerate machine identity and SSH keys.
- Install FlatCMS Home Server first-run wizard.

## Phase 4 - Cloudflare Tunnel

Goal: remove customer NAT requirements.

- Install `cloudflared`.
- Support token-based tunnel registration.
- Validate public URL.
- Add tunnel healthcheck and repair.

## Phase 5 - Synology Path

Goal: package FlatCMS for DSM separately.

- Reuse existing DSM package work.
- Add Web Station checks.
- Add aaPanel alternative guidance, because aaPanel is not the natural Synology path.

