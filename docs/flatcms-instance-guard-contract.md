# FlatCMS Instance Guard Contract

## Objective

FHSE must not become a generic publication appliance for arbitrary websites.

Cloudflare Tunnel publication must only be available when FHSE detects a valid FlatCMS installation in the expected website root:

- `/www/wwwroot/default/`

## Enforcement rule

Local hosting may still exist for diagnostics or recovery, but **publication actions** must be blocked when FlatCMS is not detected.

This applies to:

- Tunnel configuration
- Tunnel enable
- Tunnel restart
- Tunnel status promoted as `published`

## Detection model

Detection should not rely on a single file.

FHSE should validate a combination of:

### 1. Webroot path

Expected root:

- `/www/wwwroot/default/`

Expected public root:

- `/www/wwwroot/default/public/`

### 2. Core FlatCMS markers

At minimum:

- `/www/wwwroot/default/public/index.php`
- `/www/wwwroot/default/app/`
- `/www/wwwroot/default/themes/`
- `/www/wwwroot/default/public/assets/`

### 3. FHSE sentinel file

FHSE should create and maintain a dedicated sentinel file after the initial FlatCMS deployment:

- `/www/wwwroot/default/.fhse-flatcms-instance.json`

## Sentinel file contract

Suggested structure:

```json
{
  "product": "flatcms",
  "fhse_managed": true,
  "instance_id": "uuid-or-random-id",
  "installed_at": "2026-07-11T14:00:00+02:00",
  "flatcms_package_sha256": "official-package-checksum",
  "web_root": "/www/wwwroot/default",
  "public_root": "/www/wwwroot/default/public"
}
```

## Validation levels

FHSE should expose a detection result more precise than just true or false.

Recommended states:

- `flatcms_detected`
- `flatcms_missing`
- `flatcms_webroot_missing`
- `flatcms_core_files_missing`
- `flatcms_sentinel_missing`
- `flatcms_sentinel_invalid`
- `flatcms_instance_mismatch`

## Publication gating rule

Cloudflare publication is allowed only when:

- core FlatCMS markers are present
- sentinel file is present
- sentinel content is valid
- expected webroot matches the current runtime

Otherwise:

- configuration actions return a refusal
- enable returns a refusal
- restart returns a refusal
- status is downgraded from `published` to a blocked state

## FHSE local API contract

The future FHSE local agent should expose this detection explicitly.

Example capability payload:

```json
{
  "fhse": true,
  "version": "0.18.2",
  "flatcms": {
    "detected": false,
    "status": "flatcms_core_files_missing",
    "web_root": "/www/wwwroot/default"
  },
  "features": {
    "cloudflare_tunnel": {
      "supported": true,
      "configured": true,
      "active": false,
      "allowed": false
    }
  }
}
```

## FlatCMS-side UX consequence

When FlatCMS calls FHSE for Tunnel actions and FHSE reports that FlatCMS is not validly detected:

- FlatCMS must show a clear blocked state
- FlatCMS must not present Tunnel as active
- FlatCMS must explain that publication is unavailable because the managed FlatCMS instance is missing or altered

## Recommended error messages

Recommended machine-readable error codes:

- `flatcms_not_detected`
- `flatcms_sentinel_missing`
- `flatcms_installation_invalid`
- `flatcms_publication_not_allowed`

Recommended user-facing wording:

- “FlatCMS was not detected in the expected FHSE website root.”
- “Cloudflare Tunnel publication is available only for the FlatCMS instance managed by FHSE.”

## Nginx behavior when FlatCMS is absent

Do not silently publish unrelated website content.

Recommended behavior:

- local access may keep a controlled maintenance page for diagnostics
- Tunnel publication must never point to an arbitrary replacement site
- if publication had been enabled previously and FlatCMS is no longer detected, FHSE should either:
  - disable the Tunnel automatically, or
  - serve a controlled FHSE guard page with a non-success operational status

Preferred behavior:

- disable or block publication and return a controlled `503` guard page instead of exposing foreign content

## Why a guard page is preferred to a raw crash

A raw failure is unclear for:

- the user
- support
- diagnostics

A controlled guard page makes it explicit that:

- FHSE is running
- publication is intentionally blocked
- FlatCMS is missing or no longer valid

## Transition strategy

### Current validated state

FHSE local installation remains valid as is.

### Next implementation phase

Introduce:

- sentinel file creation during FlatCMS deployment
- FlatCMS detection service in FHSE
- publication gating in the future local FHSE agent
- FlatCMS Admin integration as the only public Tunnel control surface

