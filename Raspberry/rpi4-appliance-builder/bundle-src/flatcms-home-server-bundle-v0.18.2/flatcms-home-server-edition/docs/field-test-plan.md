# Field Test Plan

## Recommended First Test

Start with the Intel NUC or the old Intel Celeron PC using an existing clean Ubuntu Server 22.04 installation.

For an Apple Silicon UTM test VM, use the `arm64-vm` profile instead of `mini-pc`.

This avoids mixing two problems at once:

- OS imaging and boot automation;
- FlatCMS Home Server stack installation.

## Test Command

Copy the project folder to the target machine, then run:

```bash
sudo ./installer/install.sh ./examples/flatcms-home-server.env.example
```

For UTM on Apple Silicon, set:

```env
FLATCMS_PROFILE=arm64-vm
```

## Test Order

1. NUC with profile `mini-pc`.
2. Old Celeron PC with profile `legacy-pc`.
3. Raspberry Pi 4 with profile `raspberry-pi`.
4. Synology DS120 with a DSM-specific package path later.

## Expected MVP Result

The installer should:

- validate OS, architecture, RAM, and network;
- install base packages;
- install aaPanel;
- prepare a temporary FlatCMS placeholder page;
- create a report at `/var/log/flatcms-home-server/report.env`;
- provide the aaPanel URL when aaPanel exposes it through the `bt` command;
- provide a local FlatCMS URL.

## Known MVP Limitations

- It does not yet build a bootable ISO.
- It does not yet flash Raspberry Pi images.
- It does not yet install the real FlatCMS package.
- Cloudflare Tunnel is represented as a planned step and not fully implemented.
- The final HTML screen is a UI mockup and is not yet wired to the report file.

## Stop Conditions

Stop the test and export logs if:

- `01-preflight.sh` fails on OS or architecture;
- aaPanel install fails;
- the generated aaPanel URL is missing;
- the local HTTP healthcheck fails after aaPanel is installed.

## Logs

Installer log:

```bash
/var/log/flatcms-home-server/install.log
```

Report:

```bash
/var/log/flatcms-home-server/report.env
```
