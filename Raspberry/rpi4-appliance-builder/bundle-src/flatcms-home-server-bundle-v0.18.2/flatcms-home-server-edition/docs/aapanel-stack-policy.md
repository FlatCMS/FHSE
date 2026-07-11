# aaPanel Stack Policy

## Goal

aaPanel should be available as the customer control panel, but FlatCMS Home Server Edition should control the initial server stack.

The customer should not be exposed to the aaPanel first-login "One-click" stack recommendation as the main setup path.

## Why

FlatCMS core does not require MySQL by default. A generic LEMP/LAMP one-click install can add unnecessary services:

- MySQL or MariaDB;
- phpMyAdmin;
- FTP;
- DNS server;
- mail server;
- Apache or OpenLiteSpeed alternatives.

For the Home Server product, the default stack should stay small and predictable.

## Default FlatCMS Stack

| Component | Default | Reason |
| --- | --- | --- |
| Web server | Nginx 1.24 | Lightweight, predictable, good reverse proxy support |
| PHP | PHP 8.5 | FlatCMS runtime, available directly in the aaPanel stack selector |
| Database | None by default | FlatCMS is flat-file first |
| Redis | Optional | Cache/session acceleration |
| FTP | Pure-FTPd enabled for simple profiles | Useful for media, theme, backup, and customer file access |
| DNS server | Disabled | Cloudflare or router/local DNS handles this |
| Mail server | Disabled | Use SMTP provider or external service |
| phpMyAdmin | Disabled | No database by default |

## FTP Policy

Pure-FTPd can be enabled by default for customer-friendly profiles because many users understand FTP clients better than SSH.

Recommended rules:

- enable Pure-FTPd for `mini-pc`, `legacy-pc`, and Raspberry customer profiles;
- create one restricted FTP account mapped to the FlatCMS site directory;
- never expose the full server filesystem through FTP;
- prefer FTPS when public exposure is needed;
- keep SSH/SFTP available for administrator-level maintenance;
- do not enable anonymous FTP.

The product wording should stay simple: "File access for themes, media, and backups".

## FlatCMS Standard Stack

This is the default stack for FlatCMS Home Server Edition:

| Component | Enabled | Version / choice |
| --- | --- | --- |
| Nginx | Yes | Nginx 1.24 |
| PHP | Yes | PHP 8.5 |
| Pure-FTPd | Yes | Pure-FTPd 1.0 |
| MySQL/MariaDB | No | Disabled by default |
| phpMyAdmin | No | Disabled by default |
| DNS Server | No | Disabled by default |
| Mail Server | No | Disabled by default |

This keeps the server aligned with FlatCMS' flat-file architecture while preserving easy file access for the customer.

PHP 8.5 should be treated as the target version for the current aaPanel 8.0.4 test path. Before release, FlatCMS must pass an explicit compatibility check on PHP 8.5. If a blocking issue appears, the installer should fall back to the latest validated PHP 8.x version.

## MVP Behavior

For the current MVP, the installer may use Ubuntu packages to serve a placeholder page. This is acceptable for validating healthchecks.

The production path should later choose one of these approaches:

1. Install the chosen aaPanel runtime components programmatically.
2. Install Nginx/PHP at OS level and let aaPanel manage visibility where possible.
3. Provide a FlatCMS-specific aaPanel plugin or app template.

## First Panel Access

The final user should open aaPanel only after FlatCMS Home Server has:

- installed or selected the web server;
- installed PHP;
- created the FlatCMS site root;
- configured the initial virtual host;
- completed healthchecks;
- generated the final aaPanel URL.

## User-Facing Rule

Do not show "Apache vs Nginx vs OpenLiteSpeed" or "MySQL vs phpMyAdmin" as the first product decision.

The first product decision should be:

- local only;
- public via Cloudflare Tunnel;
- advanced manual network mode.
