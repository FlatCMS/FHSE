# FlatCMS Home Server Edition

FlatCMS Home Server Edition is an installer concept for turning small local hardware into a ready-to-use FlatCMS hosting appliance.

The product goal is simple:

> Boot, choose the hardware profile, fill in the setup form, install, verify, open aaPanel or FlatCMS.

## Target Hardware

| Profile | Hardware | Installation mode | Status |
| --- | --- | --- | --- |
| `raspberry-pi` | Raspberry Pi 4/400 | Preinstalled Ubuntu arm64 image + first boot wizard | MVP target |
| `mini-pc` | Intel NUC / N100 / N150 / similar | Bootable USB ISO | MVP target |
| `legacy-pc` | Older Intel Celeron PC | Bootable USB ISO | MVP target |
| `synology-nas` | Synology DS120 and similar | DSM package / Web Station integration | Separate package path |
| `proxmox` | Proxmox host | VM template / LXC template | Later target |

## MVP Scope

The first testable version should not try to build the final commercial USB key immediately. It should validate:

- hardware detection;
- network readiness;
- Ubuntu 22.04 based installation path;
- aaPanel installation;
- Nginx/PHP stack readiness;
- FlatCMS deployment path;
- Cloudflare Tunnel mode;
- final links to aaPanel and FlatCMS;
- healthchecks after every step.

## Installer Flow

1. Boot installer or first boot wizard.
2. Select hardware profile.
3. Fill configuration form.
4. Run preflight checks.
5. Install OS or validate existing OS.
6. Install server stack.
7. Install FlatCMS.
8. Configure public access.
9. Run final healthcheck.
10. Show success screen with:
    - aaPanel URL;
    - FlatCMS local URL;
    - FlatCMS public URL when configured;
    - diagnostic report.

## Current Files

```text
docs/
  product-spec.md
  hardware-matrix.md
  mvp-roadmap.md
  aapanel-stack-policy.md
  v0.5-aapanel-stack-test.md
  v0.6-aapanel-auto-stack.md
  v0.7-routing-default.md
  v0.8-default-site-routing.md
examples/
  flatcms-home-server.env.example
installer/
  install.sh
  lib/common.sh
  profiles/*.profile
  steps/*.sh
  healthchecks/*.sh
wizard-ui/
  final-screen.html
```

## Important Notes

- Raspberry Pi should use the Raspberry Pi compatible Ubuntu preinstalled server image, not a generic PC ISO.
- Mini PC and older Celeron PC can use a bootable amd64 ISO path.
- Synology DS120 should not be treated as a normal boot USB target. It needs a DSM package or Web Station integration workflow.
- Cloudflare Tunnel is the recommended public access mode to avoid customer-side NAT/router configuration.

## V0.9 Field Notes

- The embedded FlatCMS package is built from the supplied `FlatCMS-main.zip` core package.
- The default aaPanel stack is Nginx 1.24 + PHP 8.5. Pure-Ftpd remains disabled by default.
- PHP `fileinfo` is required. The installer checks it and tries to build the extension from aaPanel PHP sources when missing.
- FlatCMS is deployed to `/www/wwwroot/default` with `/public` as the running directory.
- The installer writes the FlatCMS vhost as `<site-name>.conf`, where the default site name is the local IPv4 address.
- `0.default.conf` is kept as a neutral fallback to avoid duplicate `server_name <IP>` conflicts.
- aaPanel `.user.ini` open_basedir locks are removed and the vhost sets `open_basedir=/www/wwwroot/default/:/tmp/`.

## V0.10 Field Notes

- PHP-FPM 8.5 is reloaded after the `fileinfo` check/build so the web runtime sees the extension.
- The FlatCMS clean URL rewrite is written to `/www/server/panel/vhost/rewrite/<site>.conf`.
- The generated Nginx vhost includes that rewrite file instead of using a generic `try_files` rule.

## V0.11 Field Notes

- The installer now tries to create the PHP Website through aaPanel internals before writing the final FlatCMS vhost.
- If aaPanel accepts the site, it appears in `Website` and the report contains `AAPANEL_SITE_STATUS=official`.
- If aaPanel refuses the internal call, the installer keeps the V0.10 generated-vhost fallback and reports `AAPANEL_SITE_STATUS=manual-vhost`.

## V0.12 Field Notes

- The aaPanel Website helper now adds `/www/server/panel/class_v2` to `sys.path`, which is where aaPanel 8.0.4 stores `panel_site_v2.py`.
- The generated FlatCMS vhost supports `/index.php/<route>` with `PATH_INFO`, matching the aaPanel URL Rewrite rule used for clean FlatCMS routes.
- The installer reloads aaPanel Nginx and PHP-FPM 8.5 through `/etc/init.d` first, with service/binary fallbacks, to avoid needing a full server reboot after installation.

## V0.13 Field Notes

- The aaPanel Website helper now passes `validate=0` to match aaPanel 8.0.4's newer `AddSite` expectations.
- The final FlatCMS route healthcheck retries briefly and accepts the FlatCMS session cookie or installer page markers, avoiding a false `unknown` while PHP-FPM/Nginx finish settling.

## V0.14 Field Notes

- The aaPanel Website helper now provides `validate()` as a method on the request object instead of passing `validate` as a scalar field.
- This targets aaPanel 8.0.4's internal `AddSite` error: `'int' object is not callable`.

## V0.15 Field Notes

- The aaPanel Website helper request object now behaves like both a dictionary and an attribute object.
- This targets aaPanel 8.0.4's internal `AddSite` call to `get.get('sub_dir', '')`.

## V0.16 Field Notes

- Adds a local Wizard Preview launched with `sudo ./start-wizard-preview.sh`.
- The wizard listens on port `8080` and drives the validated V0.15 installer from a browser.
- This preview is for UX, wording, and flow validation before building the real USB first-boot service.

## V0.17 Field Notes

- The aaPanel installer confirmation is now answered automatically with `y`.
- This fixes the Wizard Preview blocking at `Do you want to install aaPanel to the /www directory now?(y/n):`.

## V0.18 Field Notes

- The aaPanel installer now receives a continuous `yes y` stream so later prompts, including UFW/firewall confirmation, do not block the Wizard Preview.
- SSH is pre-allowed in UFW before aaPanel changes the default firewall policy.
