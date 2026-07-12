#!/usr/bin/env python3
import json
import os
import re
import shutil
import subprocess
import time
from pathlib import Path


REPORT_PATH = Path("/var/log/flatcms-home-server/report.env")
DEFAULT_WEB_ROOT = Path("/www/wwwroot/default")
DEFAULT_PUBLIC_ROOT = DEFAULT_WEB_ROOT / "public"
DEFAULT_SENTINEL_PATH = DEFAULT_WEB_ROOT / ".fhse-flatcms-instance.json"
DEFAULT_CAPABILITIES_PATH = Path("/etc/fhse/capabilities.json")
FHSE_CLOUDFLARE_DIR = Path("/etc/fhse/cloudflare")
FHSE_CLOUDFLARE_ENV_PATH = FHSE_CLOUDFLARE_DIR / "tunnel.env"
FHSE_CLOUDFLARE_KEYRING_PATH = Path("/usr/share/keyrings/cloudflare-public-v2.gpg")
FHSE_CLOUDFLARE_APT_LIST = Path("/etc/apt/sources.list.d/cloudflared.list")
FHSE_CLOUDFLARE_SERVICE_NAME = "fhse-cloudflared-tunnel.service"
FHSE_CLOUDFLARE_SERVICE_PATH = Path("/etc/systemd/system") / FHSE_CLOUDFLARE_SERVICE_NAME
FHSE_CLOUDFLARE_ENV_TOKEN_KEY = "FHSE_CLOUDFLARE_TUNNEL_TOKEN"
FHSE_CLOUDFLARE_ENV_HOSTNAME_KEY = "FHSE_CLOUDFLARE_PUBLIC_HOSTNAME"
FLATCMS_CORE_MARKERS = (
    ("file", "public/index.php"),
    ("dir", "app"),
    ("dir", "themes"),
    ("dir", "public/assets"),
)


class FhseApiError(Exception):
    def __init__(self, code, status=400, details=""):
        super().__init__(code)
        self.code = str(code).strip() or "fhse_unknown_error"
        self.status = int(status)
        self.details = str(details or "").strip()


def read_text(path, limit=0):
    try:
        text = Path(path).read_text(encoding="utf-8", errors="replace")
    except FileNotFoundError:
        return ""
    if limit > 0 and len(text) > limit:
        return text[-limit:]
    return text


def parse_env_text(text):
    values = {}
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        value = value.strip()
        if len(value) >= 2 and ((value[0] == "'" and value[-1] == "'") or (value[0] == '"' and value[-1] == '"')):
            value = value[1:-1]
        values[key.strip()] = value.replace("\\ ", " ")
    return values


def read_env_file(path):
    return parse_env_text(read_text(path, 120000))


def env_quote(value):
    normalized = str(value).replace("\n", "").replace("\r", "")
    return "'" + normalized.replace("'", "'\"'\"'") + "'"


def write_env_file(path, values, mode=0o600):
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    lines = [f"{key}={env_quote(values[key])}" for key in sorted(values.keys())]
    target.write_text("\n".join(lines) + "\n", encoding="utf-8")
    os.chmod(target, mode)


def write_json_file(path, payload, mode=0o644):
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    os.chmod(target, mode)


def write_report_value(key, value):
    existing = []
    if REPORT_PATH.exists():
        for raw in REPORT_PATH.read_text(encoding="utf-8", errors="replace").splitlines():
            if not raw.startswith(f"{key}="):
                existing.append(raw)
    existing.append(f"{key}={env_quote(value)}")
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text("\n".join(existing) + "\n", encoding="utf-8")
    os.chmod(REPORT_PATH, 0o600)


def read_json_file(path):
    target = Path(path)
    if not target.is_file():
        return None
    try:
        data = json.loads(target.read_text(encoding="utf-8", errors="replace"))
    except Exception:
        return None
    return data if isinstance(data, dict) else None


def run_command(command, check=True, timeout=300, stdin=None):
    try:
        result = subprocess.run(
            command,
            input=stdin,
            text=True if isinstance(stdin, str) else False,
            capture_output=True,
            check=False,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired as exc:
        raise FhseApiError("fhse_command_timeout", 504, " ".join(command)) from exc

    if check and result.returncode != 0:
        details = result.stderr.decode("utf-8", errors="replace") if isinstance(result.stderr, bytes) else str(result.stderr or "")
        if not details.strip():
            details = result.stdout.decode("utf-8", errors="replace") if isinstance(result.stdout, bytes) else str(result.stdout or "")
        raise FhseApiError("fhse_command_failed", 500, details.strip() or " ".join(command))

    return result


def command_succeeded(command, timeout=30):
    result = subprocess.run(command, capture_output=True, check=False, timeout=timeout)
    return result.returncode == 0


def normalize_tunnel_token(value):
    return str(value or "").replace("\r", "").replace("\n", "").strip()


def normalize_public_hostname(value):
    hostname = str(value or "").strip().lower().rstrip(".")
    return hostname


def is_valid_public_hostname(hostname):
    if hostname == "":
        return True
    if "://" in hostname or "/" in hostname or " " in hostname:
        return False
    return re.match(r"^(?=.{1,253}$)(?!-)[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.(?!-)[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+$", hostname) is not None


def is_loopback_address(address):
    return address in ("127.0.0.1", "::1", "::ffff:127.0.0.1")


def cloudflared_binary_available():
    return shutil.which("cloudflared") is not None


def service_is_active(service_name):
    return command_succeeded(["systemctl", "is-active", "--quiet", service_name])


def service_is_enabled(service_name):
    return command_succeeded(["systemctl", "is-enabled", "--quiet", service_name])


def read_tunnel_env():
    return read_env_file(FHSE_CLOUDFLARE_ENV_PATH)


def last_service_logs(service_name, lines=30):
    result = subprocess.run(
        ["journalctl", "--no-pager", "-u", service_name, "-n", str(lines)],
        capture_output=True,
        check=False,
        timeout=30,
        text=True,
    )
    return str(result.stdout or "").strip()


def build_flatcms_state(report):
    sentinel_path = Path(report.get("FHSE_SENTINEL_PATH") or DEFAULT_SENTINEL_PATH)
    sentinel = read_json_file(sentinel_path)
    sentinel_exists = sentinel_path.is_file()
    sentinel_valid = isinstance(sentinel, dict) and str(sentinel.get("product", "")).strip().lower() == "flatcms" and bool(sentinel.get("fhse_managed"))

    web_root = Path(
        (sentinel or {}).get("web_root")
        or report.get("FLATCMS_WEB_ROOT")
        or DEFAULT_WEB_ROOT
    )
    public_root = Path(
        (sentinel or {}).get("public_root")
        or report.get("FLATCMS_PUBLIC_ROOT")
        or DEFAULT_PUBLIC_ROOT
    )

    if not web_root.is_dir():
        status = "flatcms_webroot_missing"
        detected = False
    else:
        markers_ok = True
        for marker_type, relative_path in FLATCMS_CORE_MARKERS:
            target = web_root / relative_path
            if marker_type == "file" and not target.is_file():
                markers_ok = False
                break
            if marker_type == "dir" and not target.is_dir():
                markers_ok = False
                break

        if not markers_ok:
            status = "flatcms_core_files_missing"
            detected = False
        elif not sentinel_exists:
            status = "flatcms_sentinel_missing"
            detected = False
        elif not sentinel_valid:
            status = "flatcms_sentinel_invalid"
            detected = False
        else:
            status = "flatcms_detected"
            detected = True

    return {
        "detected": detected,
        "status": status,
        "web_root": str(web_root),
        "public_root": str(public_root),
        "sentinel_path": str(sentinel_path),
        "sentinel_exists": sentinel_exists,
        "sentinel_valid": sentinel_valid,
    }


def write_cloudflare_service_unit():
    unit = """[Unit]
Description=FHSE Cloudflare Tunnel
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
EnvironmentFile=/etc/fhse/cloudflare/tunnel.env
ExecStart=/bin/sh -lc 'exec /usr/bin/cloudflared tunnel --no-autoupdate run --token \"$FHSE_CLOUDFLARE_TUNNEL_TOKEN\"'
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
"""
    FHSE_CLOUDFLARE_SERVICE_PATH.parent.mkdir(parents=True, exist_ok=True)
    FHSE_CLOUDFLARE_SERVICE_PATH.write_text(unit, encoding="utf-8")
    os.chmod(FHSE_CLOUDFLARE_SERVICE_PATH, 0o644)


def ensure_cloudflared_installed():
    if cloudflared_binary_available():
        return

    run_command(["apt-get", "update"], timeout=600)
    run_command(["apt-get", "install", "-y", "ca-certificates", "curl", "gnupg"], timeout=600)
    FHSE_CLOUDFLARE_KEYRING_PATH.parent.mkdir(parents=True, exist_ok=True)
    key_result = run_command(["curl", "-fsSL", "https://pkg.cloudflare.com/cloudflare-public-v2.gpg"], timeout=120)
    key_data = key_result.stdout
    if isinstance(key_data, str):
        key_bytes = key_data.encode("utf-8")
    else:
        key_bytes = key_data or b""
    FHSE_CLOUDFLARE_KEYRING_PATH.write_bytes(key_bytes)
    os.chmod(FHSE_CLOUDFLARE_KEYRING_PATH, 0o644)
    FHSE_CLOUDFLARE_APT_LIST.write_text(
        "deb [signed-by=/usr/share/keyrings/cloudflare-public-v2.gpg] https://pkg.cloudflare.com/cloudflared any main\n",
        encoding="utf-8",
    )
    os.chmod(FHSE_CLOUDFLARE_APT_LIST, 0o644)
    run_command(["apt-get", "update"], timeout=600)
    run_command(["apt-get", "install", "-y", "cloudflared"], timeout=600)


def write_tunnel_env(token, public_hostname):
    values = {
        FHSE_CLOUDFLARE_ENV_TOKEN_KEY: normalize_tunnel_token(token),
        FHSE_CLOUDFLARE_ENV_HOSTNAME_KEY: normalize_public_hostname(public_hostname),
    }
    write_env_file(FHSE_CLOUDFLARE_ENV_PATH, values)


def sync_capabilities_file():
    report = read_env_file(REPORT_PATH)
    flatcms = build_flatcms_state(report)
    version = str(report.get("FHSE_VERSION") or "0.18.2-rpi4.1-rc3.12").strip()
    profile = str(report.get("FHSE_PROFILE") or report.get("FLATCMS_PROFILE") or "mini-pc").strip()
    capabilities_path = Path(report.get("FHSE_CAPABILITIES_PATH") or DEFAULT_CAPABILITIES_PATH)
    tunnel_env = read_tunnel_env()
    configured = normalize_tunnel_token(tunnel_env.get(FHSE_CLOUDFLARE_ENV_TOKEN_KEY, "")) != ""
    active = service_is_active(FHSE_CLOUDFLARE_SERVICE_NAME)
    hostname = normalize_public_hostname(tunnel_env.get(FHSE_CLOUDFLARE_ENV_HOSTNAME_KEY, ""))

    payload = {
        "fhse": True,
        "version": version,
        "profile": profile,
        "features": {
            "cloudflare_tunnel": {
                "supported": True,
                "configured": configured,
                "active": active,
                "allowed": flatcms["detected"],
                "mode": "token",
                "requires_flatcms": True,
                "public_hostname": hostname,
                "config_path": str(FHSE_CLOUDFLARE_ENV_PATH),
                "service_name": FHSE_CLOUDFLARE_SERVICE_NAME,
            }
        },
        "flatcms": {
            "detected": flatcms["detected"],
            "status": flatcms["status"],
            "web_root": flatcms["web_root"],
            "public_root": flatcms["public_root"],
            "sentinel": flatcms["sentinel_path"],
        },
    }

    write_json_file(capabilities_path, payload)
    write_report_value("FHSE_VERSION", version)
    write_report_value("FHSE_PROFILE", profile)
    write_report_value("FHSE_CAPABILITIES_PATH", str(capabilities_path))
    write_report_value("FHSE_SENTINEL_PATH", flatcms["sentinel_path"])
    write_report_value("FHSE_FLATCMS_DETECTED", "yes" if flatcms["detected"] else "no")
    write_report_value("CLOUDFLARE_TUNNEL_STATUS", "active" if active else ("configured" if configured else "unconfigured"))
    write_report_value("CHECK_CLOUDFLARED", "ok" if active else ("installed" if cloudflared_binary_available() else "missing"))
    write_report_value("CLOUDFLARE_TUNNEL_PUBLIC_HOSTNAME", hostname)

    return build_api_capabilities_payload(report=report, flatcms=flatcms, configured=configured, active=active, public_hostname=hostname, version=version, profile=profile, capabilities_path=capabilities_path)


def build_api_capabilities_payload(report=None, flatcms=None, configured=None, active=None, public_hostname=None, version=None, profile=None, capabilities_path=None):
    report = report or read_env_file(REPORT_PATH)
    flatcms = flatcms or build_flatcms_state(report)
    tunnel_env = read_tunnel_env()
    configured = configured if configured is not None else normalize_tunnel_token(tunnel_env.get(FHSE_CLOUDFLARE_ENV_TOKEN_KEY, "")) != ""
    active = active if active is not None else service_is_active(FHSE_CLOUDFLARE_SERVICE_NAME)
    public_hostname = public_hostname if public_hostname is not None else normalize_public_hostname(tunnel_env.get(FHSE_CLOUDFLARE_ENV_HOSTNAME_KEY, ""))
    version = version or str(report.get("FHSE_VERSION") or "0.18.2-rpi4.1-rc3.12").strip()
    profile = profile or str(report.get("FHSE_PROFILE") or report.get("FLATCMS_PROFILE") or "mini-pc").strip()
    capabilities_path = Path(capabilities_path or report.get("FHSE_CAPABILITIES_PATH") or DEFAULT_CAPABILITIES_PATH)
    capabilities_exists = capabilities_path.is_file()
    sentinel_path = Path(flatcms["sentinel_path"])

    return {
        "detected": True,
        "version": version,
        "profile": profile,
        "capabilities_file": {
            "path": str(capabilities_path),
            "exists": capabilities_exists,
            "readable": capabilities_exists,
            "valid": capabilities_exists,
            "status": "ok" if capabilities_exists else "missing",
        },
        "sentinel_file": {
            "path": str(sentinel_path),
            "exists": flatcms["sentinel_exists"],
            "readable": flatcms["sentinel_exists"],
            "valid": flatcms["sentinel_valid"],
            "status": "ok" if flatcms["sentinel_valid"] else ("invalid" if flatcms["sentinel_exists"] else "missing"),
        },
        "flatcms": {
            "detected": flatcms["detected"],
            "status": flatcms["status"],
            "web_root": flatcms["web_root"],
            "public_root": flatcms["public_root"],
        },
        "cloudflare_tunnel": {
            "supported": True,
            "configured": configured,
            "configured_known": True,
            "active": active,
            "active_known": True,
            "allowed": flatcms["detected"],
            "mode": "token",
            "public_hostname": public_hostname,
            "config_path": str(FHSE_CLOUDFLARE_ENV_PATH),
            "service_name": FHSE_CLOUDFLARE_SERVICE_NAME,
            "status_source": "fhse_local_api",
        },
    }


def current_capabilities(enforce_guard=False):
    report = read_env_file(REPORT_PATH)
    flatcms = build_flatcms_state(report)

    if enforce_guard and not flatcms["detected"] and service_is_active(FHSE_CLOUDFLARE_SERVICE_NAME):
        subprocess.run(["systemctl", "disable", "--now", FHSE_CLOUDFLARE_SERVICE_NAME], check=False, timeout=60)

    return sync_capabilities_file()


def require_flatcms_allowed():
    report = read_env_file(REPORT_PATH)
    flatcms = build_flatcms_state(report)
    if not flatcms["detected"]:
        raise FhseApiError("flatcms_publication_not_allowed", 409, flatcms["status"])
    return flatcms


def configure_tunnel(payload):
    require_flatcms_allowed()
    current = read_tunnel_env()
    token = normalize_tunnel_token(payload.get("token") or current.get(FHSE_CLOUDFLARE_ENV_TOKEN_KEY, ""))
    hostname = normalize_public_hostname(payload.get("public_hostname") or current.get(FHSE_CLOUDFLARE_ENV_HOSTNAME_KEY, ""))

    if token == "":
        raise FhseApiError("tunnel_token_missing", 422)
    if not is_valid_public_hostname(hostname):
        raise FhseApiError("tunnel_hostname_invalid", 422)

    write_tunnel_env(token, hostname)
    write_cloudflare_service_unit()
    run_command(["systemctl", "daemon-reload"], timeout=60)

    if service_is_active(FHSE_CLOUDFLARE_SERVICE_NAME):
        restart_service()

    return {
        "result": "configured",
        "capabilities": current_capabilities(enforce_guard=True),
    }


def enable_tunnel(payload):
    require_flatcms_allowed()
    current = read_tunnel_env()
    token = normalize_tunnel_token(payload.get("token") or current.get(FHSE_CLOUDFLARE_ENV_TOKEN_KEY, ""))
    hostname = normalize_public_hostname(payload.get("public_hostname") or current.get(FHSE_CLOUDFLARE_ENV_HOSTNAME_KEY, ""))

    if token == "":
        raise FhseApiError("tunnel_token_missing", 422)
    if not is_valid_public_hostname(hostname):
        raise FhseApiError("tunnel_hostname_invalid", 422)

    write_tunnel_env(token, hostname)

    try:
        ensure_cloudflared_installed()
    except FhseApiError as exc:
        raise FhseApiError("cloudflared_install_failed", exc.status, exc.details) from exc

    write_cloudflare_service_unit()
    run_command(["systemctl", "daemon-reload"], timeout=60)
    run_command(["systemctl", "enable", FHSE_CLOUDFLARE_SERVICE_NAME], timeout=60)
    run_command(["systemctl", "restart", FHSE_CLOUDFLARE_SERVICE_NAME], timeout=60)
    time.sleep(3)

    if not service_is_active(FHSE_CLOUDFLARE_SERVICE_NAME):
        raise FhseApiError("cloudflared_enable_failed", 500, last_service_logs(FHSE_CLOUDFLARE_SERVICE_NAME))

    return {
        "result": "enabled",
        "capabilities": current_capabilities(enforce_guard=True),
    }


def disable_tunnel():
    subprocess.run(["systemctl", "disable", "--now", FHSE_CLOUDFLARE_SERVICE_NAME], check=False, timeout=60)
    time.sleep(1)
    if service_is_active(FHSE_CLOUDFLARE_SERVICE_NAME):
        raise FhseApiError("cloudflared_disable_failed", 500, last_service_logs(FHSE_CLOUDFLARE_SERVICE_NAME))

    return {
        "result": "disabled",
        "capabilities": current_capabilities(enforce_guard=True),
    }


def restart_service():
    tunnel_env = read_tunnel_env()
    token = normalize_tunnel_token(tunnel_env.get(FHSE_CLOUDFLARE_ENV_TOKEN_KEY, ""))
    if token == "":
        raise FhseApiError("cloudflared_not_configured", 409)
    write_cloudflare_service_unit()
    run_command(["systemctl", "daemon-reload"], timeout=60)
    run_command(["systemctl", "restart", FHSE_CLOUDFLARE_SERVICE_NAME], timeout=60)
    time.sleep(2)
    if not service_is_active(FHSE_CLOUDFLARE_SERVICE_NAME):
        raise FhseApiError("cloudflared_restart_failed", 500, last_service_logs(FHSE_CLOUDFLARE_SERVICE_NAME))


def restart_tunnel(payload):
    require_flatcms_allowed()
    if payload:
        current = read_tunnel_env()
        has_new_token = normalize_tunnel_token(payload.get("token", "")) != ""
        has_new_hostname = normalize_public_hostname(payload.get("public_hostname", "")) != ""
        if has_new_token or has_new_hostname or normalize_tunnel_token(current.get(FHSE_CLOUDFLARE_ENV_TOKEN_KEY, "")) == "":
            configure_tunnel(payload)

    restart_service()
    return {
        "result": "restarted",
        "capabilities": current_capabilities(enforce_guard=True),
    }


def tunnel_status():
    return {
        "result": "status",
        "capabilities": current_capabilities(enforce_guard=True),
    }
