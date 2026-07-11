# FHSE v0.18.2 RC3.10 Release And Test Notes

## Local files

- image archive:
  - `/Users/alain/Downloads/FHSE/fhse-rpi4-v0.18.2-rpi4.1-rc3.10.img.xz`
- raw image:
  - `/Users/alain/Downloads/FHSE/fhse-rpi4-v0.18.2-rpi4.1-rc3.10.img`
- checksum file:
  - `/Users/alain/Downloads/FHSE/fhse-rpi4-v0.18.2-rpi4.1-rc3.10.img.sha256`
- build log:
  - `/Users/alain/Downloads/FHSE/fhse-rpi4-v0.18.2-rpi4.1-rc3.10-build.log`

## Can this image be flashed with Raspberry Pi Imager?

Yes.

Recommended path:

1. Open Raspberry Pi Imager.
2. Choose `Use custom`.
3. Select `fhse-rpi4-v0.18.2-rpi4.1-rc3.10.img.xz`.
4. Choose the target SSD.
5. Start flashing.

Fallback:

- if your Raspberry Pi Imager build refuses the compressed archive, select the uncompressed `fhse-rpi4-v0.18.2-rpi4.1-rc3.10.img` instead

Reference:

- Raspberry Pi documents the `Use custom` flow for installing an OS image stored on your computer:
  [Raspberry Pi Imager documentation](https://www.raspberrypi.com/documentation/computers/getting-started.html#raspberry-pi-imager)

## Recommended live test flow on Raspberry Pi 400

1. Flash the SSD with Raspberry Pi Imager.
2. Boot the Raspberry Pi 400 from the SSD.
3. Wait for the initial provisioning to complete.
4. From another machine on the same LAN, open:
   - `http://fhse.local:8080`
5. If mDNS resolution is unavailable on the LAN, use the device IP instead.
6. Complete the wizard.
7. Confirm that aaPanel is reachable and that FlatCMS is present in the default website root.

## Expected functional checks

- FHSE wizard loads on the local network
- Ubuntu technical access is not exposed with a default password
- SSH password auth stays disabled until explicitly enabled by the wizard
- Cloudflare Tunnel is optional and clearly presented as such
- aaPanel is installed and usable
- Nginx is installed and serving the default website
- PHP 8.5 and required extensions are present
- FlatCMS is deployed in aaPanel default web root
- FlatCMS front and admin are reachable after provisioning

## Suggested checklist for Patrick / RaspberryTips

- installation time on Raspberry Pi 400
- first boot clarity for non-technical users
- wizard accessibility from another device on the LAN
- aaPanel visibility and usefulness for website management
- FlatCMS availability immediately after setup
- optional Cloudflare Tunnel flow clarity
- SSD-based performance and general stability

## Build traceability

- remote build workspace was cleaned after successful artifact recovery
- final build log was preserved locally
- image checksums were verified locally after download

