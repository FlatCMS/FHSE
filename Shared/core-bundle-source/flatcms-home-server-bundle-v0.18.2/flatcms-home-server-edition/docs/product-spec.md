# Product Spec

## Name

FlatCMS Home Server Edition

## Positioning

FlatCMS Home Server Edition is a guided local hosting appliance for FlatCMS. It lets a customer host a professional website on their own hardware without learning Linux administration, NAT, reverse proxy configuration, or manual SSL setup.

## Promise

No command line for the final customer. No router port forwarding. No complex server administration.

## Customer Journey

1. Customer buys the FlatCMS Home Server USB key or downloads the installer image.
2. Customer boots the target hardware.
3. The installer opens a wizard.
4. Customer selects the hardware profile.
5. Customer fills in account, domain, and access settings.
6. Installer runs each step with a visible status.
7. If an error occurs, the wizard offers diagnostics, repair, retry, or restart.
8. On success, the customer sees buttons for aaPanel and the FlatCMS site.

## Hardware Choice Screen

- FlatCMS Home Server for Raspberry Pi
- FlatCMS Home Server for Mini PC
- FlatCMS Home Server for NAS
- FlatCMS Home Server for Proxmox
- FlatCMS Home Server ISO

## Recommended Public Access

Cloudflare Tunnel should be the default recommendation because it avoids:

- router NAT rules;
- opening ports 80 and 443;
- dynamic public IP issues;
- many ISP CGNAT limitations.

## Final Success Screen

The final screen must show:

- aaPanel service status;
- FlatCMS service status;
- Nginx status;
- PHP status;
- Cloudflare Tunnel status when enabled;
- local URL;
- public URL when enabled;
- two primary buttons:
  - Access my Panel;
  - Open my FlatCMS site.

## aaPanel First Login

aaPanel may display a recommended one-click stack installation at first login. FlatCMS Home Server Edition should not rely on the customer completing this technical screen manually.

The product installer should install or select the FlatCMS-approved stack before the final "Access my Panel" button is shown.

## Security Rules

- No shared default password in production images.
- SSH host keys must be regenerated on first boot.
- `/etc/machine-id` must be regenerated on first boot.
- aaPanel entry URL and credentials must be generated per installation.
- Cloudflare tokens must be supplied by the customer or via a secure short-lived pairing flow.
- Installer logs must redact secrets.
- Diagnostics should be exportable without exposing passwords or tokens.
