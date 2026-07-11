# Cloudflare Tunnel Publication Model

## Decision

Cloudflare Tunnel publication should not remain a primary interactive feature of the FHSE local installation wizard.

FHSE should install and expose the server-side capability, while FlatCMS should become the only user-facing interface used to publish a FlatCMS site through Cloudflare Tunnel.

## Product split

### FlatCMS

FlatCMS remains responsible for:

- the user-facing interface
- the CMS-side publication workflow
- the settings screen
- the publication status display
- the hostname and publication actions visible to the user

### FHSE

FHSE remains responsible for:

- local server capability detection
- secure local system orchestration
- `cloudflared` installation
- service configuration
- service restart / disable / status checks
- local execution of privileged actions

## Why this model is preferred

This avoids turning FHSE into a second public-facing admin product.

It also prevents the publication workflow from becoming a generic appliance feature that could be reused independently of FlatCMS by simply replacing the website files under:

- `/www/wwwroot/default/`

With the publication flow initiated from FlatCMS only, the commercial and product boundary stays clear:

- FlatCMS = CMS + publication UI
- FHSE = appliance + privileged execution layer

## Functional target

The recommended user journey is:

1. install FHSE locally
2. use FlatCMS locally during development
3. when the site is ready, open FlatCMS Admin
4. go to `Settings -> Integrations & API -> Cloudflare`
5. configure the Cloudflare Tunnel publication there
6. FlatCMS delegates the privileged action to FHSE

## Local capability detection

FHSE should expose a local machine-readable file, for example:

- `/etc/fhse/capabilities.json`

Expected role:

- declare that FHSE is present
- expose supported server-side features
- tell FlatCMS whether Cloudflare Tunnel is available, configured, and active

## Local orchestration API

FHSE should expose a local-only secured API or agent.

Recommended properties:

- no public WAN exposure
- local-only access
- Unix socket preferred, loopback HTTP acceptable
- authenticated requests

Expected first endpoints:

- capabilities
- tunnel status
- tunnel configure
- tunnel enable
- tunnel disable
- tunnel restart

## FlatCMS UI placement

The natural UI location is:

- `Settings -> Integrations & API -> Cloudflare`

The split inside FlatCMS should be:

- `Cloudflare Turnstile`
  - always available
- `Cloudflare Tunnel`
  - visible only when FHSE capability is detected

## Transition strategy

### RC3.10

Keep the current validated local installation flow.

Cloudflare can still remain optional there for compatibility with the already validated appliance behavior.

### Next FHSE / FlatCMS evolution

Move the real publication workflow into FlatCMS and progressively reduce the FHSE wizard to:

- local-first installation
- optional informational hints about later publication
- no primary Tunnel setup UX in the appliance wizard

## Testing priority

On Apple Silicon with UTM, prioritize:

- Ubuntu ARM64
- Debian ARM64

These are much more representative and faster than x86_64 emulation on the same host.

x86_64 VM validation remains useful later on:

- VirtualBox
- VMware
- KVM / Proxmox

