# FlatCMS Home Server Installer V0.18.2

This local web installer runs the FlatCMS Home Server setup step by step.

Start it from the bundle root:

```bash
sudo ./start-wizard-preview.sh
```

Then open the displayed URL from another machine on the same network:

```text
http://VM_IP:8080
```

## V0.18.2 behavior

The wizard no longer starts one long automatic installation.
Each server operation is launched separately by the user:

1. Prepare Ubuntu Server
2. Install aaPanel
3. Install Nginx
4. Install PHP 8.5 + fileinfo
5. Create the aaPanel Website
6. Deploy FlatCMS
7. Run final checks

After each step, the interface shows a green confirmation and the user chooses when to continue.
The technical logs are hidden by default and available through “Afficher les détails techniques”.

## Runtime files

Step states:

```text
/var/lib/flatcms-home-server/wizard/steps/*.env
```

Step logs:

```text
/var/log/flatcms-home-server/steps/*.log
```

Final report:

```text
/var/log/flatcms-home-server/report.env
```

aaPanel credentials:

```text
/var/log/flatcms-home-server/aapanel-credentials.env
```

The installer remains intentionally local-only for this preview:

- Cloudflare Tunnel setup is available when a tunnel token is provided;
- no Let's Encrypt automation yet;
- no permanent first-boot service yet.
