#!/usr/bin/env python3
import argparse
import json
import os
import re
import shlex
import signal
import subprocess
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse, urlsplit

from fhse_cloudflare import (
    FhseApiError,
    configure_tunnel,
    current_capabilities,
    disable_tunnel,
    enable_tunnel,
    is_loopback_address,
    restart_tunnel,
    tunnel_status,
)


BUNDLE_DIR = Path(__file__).resolve().parents[1]
INSTALLER_DIR = BUNDLE_DIR / "flatcms-home-server-edition"
BASE_CONFIG = INSTALLER_DIR / "examples" / "flatcms-home-server-arm64-vm.env.example"
PACKAGE_ZIP = BUNDLE_DIR / "packages" / "flatcms.zip"
INDEX_HTML = Path(__file__).resolve().parent / "index.html"

STATE_DIR = Path("/var/lib/flatcms-home-server/wizard")
STEP_STATE_DIR = STATE_DIR / "steps"
STATE_PATH = STATE_DIR / "state.json"
RUNTIME_CONFIG = STATE_DIR / "runtime.env"
RUNNER_DIR = STATE_DIR / "runners"

LOG_DIR = Path("/var/log/flatcms-home-server")
REPORT_PATH = LOG_DIR / "report.env"
INSTALL_LOG = LOG_DIR / "install.log"
CREDENTIALS_PATH = LOG_DIR / "aapanel-credentials.env"
STEP_LOG_DIR = LOG_DIR / "steps"
ISSUE_PATH = Path("/etc/issue.d/fhse.issue")
SSH_PASSWORD_CONFIG_PATH = Path("/etc/ssh/sshd_config.d/99-fhse-password-auth.conf")
AAPANEL_SSL_FLAG = Path("/www/server/panel/data/ssl.pl")

TECHNICAL_ACCESS_USER = "admin"
MIN_TECHNICAL_PASSWORD_LENGTH = 8

PRODUCT_STEPS = [
    {
        "id": "system",
        "number": 3,
        "title": "Installation de l’OS Linux",
        "subtitle": "Ubuntu Server 22.04.5 LTS",
        "headline": "Installation de l’OS Linux",
        "description": "FHSE vérifie Ubuntu Server, l’architecture ARM64, le réseau et installe les dépendances système nécessaires au fonctionnement du serveur.",
        "success": "Ubuntu Server est prêt.",
        "action": "Préparer l’OS Linux",
        "scripts": ["steps/01-preflight.sh", "steps/02-system-base.sh"],
    },
    {
        "id": "panel",
        "number": 4,
        "title": "Installation du panel serveur",
        "subtitle": "aaPanel 8.0.4",
        "headline": "Installation du panel serveur",
        "description": "aaPanel est installé comme panneau d’administration serveur avancée. Son accès sera disponible une fois l’installation terminée.",
        "success": "aaPanel 8.0.4 est installé.",
        "action": "Installer aaPanel",
        "scripts": ["steps/03-install-aapanel.sh"],
    },
    {
        "id": "nginx",
        "number": 5,
        "title": "Installation serveur web",
        "subtitle": "Nginx 1.24.0",
        "headline": "Installation serveur web",
        "description": "Nginx 1.24.0 est installé comme serveur web principal pour publier FlatCMS.",
        "success": "Nginx 1.24.0 est installé et actif.",
        "action": "Installer Nginx",
        "scripts": ["steps/03b-install-nginx.sh"],
    },
    {
        "id": "php",
        "number": 6,
        "title": "Installation moteur PHP",
        "subtitle": "PHP 8.5 + fileinfo",
        "headline": "Installation moteur PHP",
        "description": "PHP-FPM 8.5 et l’extension fileinfo sont installés pour exécuter FlatCMS correctement.",
        "success": "PHP 8.5 et fileinfo sont installés.",
        "action": "Installer PHP 8.5",
        "scripts": ["steps/03c-install-php.sh"],
    },
    {
        "id": "site",
        "number": 7,
        "title": "Création espace web",
        "subtitle": "Dossier privé et public",
        "headline": "Création espace web",
        "description": "Le dossier privé, le répertoire public et le vhost Nginx sont créés pour servir FlatCMS à la racine du domaine.",
        "success": "L’espace web FlatCMS est créé et configuré.",
        "action": "Créer l’espace web",
        "scripts": ["steps/04a-create-aapanel-site.sh"],
    },
    {
        "id": "flatcms",
        "number": 8,
        "title": "Installation de FlatCMS",
        "subtitle": "Déploiement de votre CMS",
        "headline": "Installation de FlatCMS",
        "description": "FlatCMS est déployé, les permissions sont ajustées et la configuration locale est créée.",
        "success": "FlatCMS est installé sur votre serveur.",
        "action": "Installer FlatCMS",
        "scripts": ["steps/04b-install-flatcms.sh"],
    },
    {
        "id": "checks",
        "number": 9,
        "title": "Vérifications finales",
        "subtitle": "Création du rapport",
        "headline": "Vérifications finales",
        "description": "FHSE finalise la configuration, vérifie l’accès local puis génère le rapport final de l’installation.",
        "success": "Le rapport final est créé.",
        "action": "Finaliser",
        "scripts": ["steps/06-final-report.sh", "healthchecks/final-healthcheck.sh"],
    },
]
STEP_MAP = {step["id"]: step for step in PRODUCT_STEPS}
ORDER = [step["id"] for step in PRODUCT_STEPS]
ANSI_RE = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")


def ensure_dirs():
    for path in (STATE_DIR, STEP_STATE_DIR, RUNNER_DIR, LOG_DIR, STEP_LOG_DIR):
        path.mkdir(parents=True, exist_ok=True)


def now():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")


def read_text(path, limit=20000):
    try:
        text = Path(path).read_text(encoding="utf-8", errors="replace")
    except FileNotFoundError:
        return ""
    if limit and len(text) > limit:
        return text[-limit:]
    return text


def parse_env_text(text):
    values = {}
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        try:
            parsed = shlex.split(value, posix=True)
            values[key] = parsed[0] if parsed else ""
        except Exception:
            values[key] = value.strip().strip("'\"").replace("\\ ", " ")
    return values


def read_env_file(path):
    return parse_env_text(read_text(path, 80000))


def env_quote(value):
    value = str(value).strip().replace("\n", "")
    return shlex.quote(value)


def shell_quote(value):
    return shlex.quote(str(value))


def first_local_ip():
    try:
        output = subprocess.check_output(["hostname", "-I"], text=True).strip()
        for item in output.split():
            if re.match(r"^\d+\.\d+\.\d+\.\d+$", item):
                return item
    except Exception:
        pass
    return "127.0.0.1"


def normalize_local_aapanel_url(url):
    local_ip = first_local_ip()
    if not url or not local_ip:
        return url
    parsed = urlsplit(url)
    if not parsed.scheme or not parsed.netloc:
        return url
    port = f":{parsed.port}" if parsed.port else ""
    path = parsed.path or ""
    if parsed.query:
        path = f"{path}?{parsed.query}"
    if parsed.fragment:
        path = f"{path}#{parsed.fragment}"
    return f"{parsed.scheme}://{local_ip}{port}{path}"


def aapanel_panel_ssl_enabled(report=None):
    if AAPANEL_SSL_FLAG.exists():
        return True
    if report and str(report.get("AAPANEL_PANEL_SSL", "")).strip().lower() == "enabled":
        return True
    return False


def enforce_local_aapanel_url_scheme(url, report=None):
    normalized = normalize_local_aapanel_url(url)
    if not normalized:
        return normalized
    if not aapanel_panel_ssl_enabled(report) and normalized.startswith("https://"):
        return f"http://{normalized[len('https://'):]}"
    return normalized


def aapanel_backend_context(credentials=None, report=None):
    credentials = credentials or refresh_credentials()
    report = report or read_env_file(REPORT_PATH)
    backend_url = credentials.get("AAPANEL_URL") or report.get("AAPANEL_URL", "")
    backend_url = enforce_local_aapanel_url_scheme(backend_url, report)
    if not backend_url:
        return {}

    parsed = urlsplit(backend_url)
    if not parsed.scheme or not parsed.netloc:
        return {}

    return {
        "backend_url": backend_url,
        "scheme": parsed.scheme,
        "netloc": parsed.netloc,
    }


def parse_aapanel_info(text):
    data = {}
    urls = []
    report = read_env_file(REPORT_PATH)
    local_ip = first_local_ip()
    for line in text.splitlines():
        stripped = ANSI_RE.sub("", line).strip()
        if not stripped:
            continue
        lower = stripped.lower()
        url_match = re.search(r"https?://(?:\[[^\]]+\]|[^\s]+)", stripped)
        if url_match:
            url = url_match.group(0).rstrip(".,;)")
            priority = 1
            if "internal" in lower or local_ip in url:
                priority = 3
            elif re.search(r"https?://(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)", url):
                priority = 2
            urls.append((priority, url))
        if "username" in lower or lower.startswith("user"):
            data["AAPANEL_USERNAME"] = stripped.split(":", 1)[-1].strip()
        elif "password" in lower:
            data["AAPANEL_PASSWORD"] = stripped.split(":", 1)[-1].strip()
    if urls:
        urls.sort(key=lambda item: item[0])
        data["AAPANEL_URL"] = enforce_local_aapanel_url_scheme(urls[-1][1], report)
    return {k: v for k, v in data.items() if v}


def save_credentials(credentials):
    if not credentials:
        return
    CREDENTIALS_PATH.parent.mkdir(parents=True, exist_ok=True)
    lines = []
    for key in ("AAPANEL_URL", "AAPANEL_USERNAME", "AAPANEL_PASSWORD"):
        if credentials.get(key):
            lines.append(f"{key}={env_quote(credentials[key])}")
    CREDENTIALS_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")
    os.chmod(CREDENTIALS_PATH, 0o600)


def refresh_credentials():
    credentials = read_env_file(CREDENTIALS_PATH)
    if credentials.get("AAPANEL_URL"):
        normalized_url = enforce_local_aapanel_url_scheme(
            credentials["AAPANEL_URL"],
            read_env_file(REPORT_PATH),
        )
        if normalized_url != credentials["AAPANEL_URL"]:
            credentials["AAPANEL_URL"] = normalized_url
            save_credentials(credentials)
    if credentials.get("AAPANEL_URL") and credentials.get("AAPANEL_USERNAME") and credentials.get("AAPANEL_PASSWORD"):
        return credentials
    if os.geteuid() != 0:
        return credentials
    try:
        output = subprocess.check_output(["bt", "14"], text=True, stderr=subprocess.DEVNULL, timeout=6)
    except Exception:
        output = ""
    parsed = parse_aapanel_info(output)
    if not parsed:
        for path in (LOG_DIR / "aapanel-install-output.log", LOG_DIR / "aapanel-bt14-output.log"):
            parsed = parse_aapanel_info(read_text(path, 50000))
            if parsed:
                break
    if parsed:
        merged = dict(credentials)
        merged.update(parsed)
        save_credentials(merged)
        return merged
    return credentials


def default_state():
    return {
        "mode": "step-by-step",
        "status": "idle",
        "message": "Assistant prêt",
        "active_step": "",
        "started_at": "",
        "finished_at": "",
        "pid": None,
        "runtime_config": str(RUNTIME_CONFIG) if RUNTIME_CONFIG.exists() else "",
        "technical_access": {
            "configured": False,
            "user": TECHNICAL_ACCESS_USER,
            "ssh_password_auth_enabled": False,
            "updated_at": "",
        },
    }


def read_state():
    if not STATE_PATH.exists():
        return default_state()
    try:
        data = json.loads(STATE_PATH.read_text(encoding="utf-8"))
        merged = default_state()
        merged.update(data)
        technical_access = merged.get("technical_access")
        default_technical_access = default_state()["technical_access"]
        if not isinstance(technical_access, dict):
            merged["technical_access"] = dict(default_technical_access)
        else:
            normalized_technical_access = dict(default_technical_access)
            normalized_technical_access.update(technical_access)
            merged["technical_access"] = normalized_technical_access
        return merged
    except Exception:
        return default_state()


def write_state(**updates):
    ensure_dirs()
    data = read_state()
    data.update(updates)
    STATE_PATH.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    return data


def step_state_path(step_id):
    return STEP_STATE_DIR / f"{step_id}.env"


def step_log_path(step_id):
    return STEP_LOG_DIR / f"{step_id}.log"


def read_step_state(step_id):
    data = read_env_file(step_state_path(step_id))
    if not data:
        return {"STATUS": "pending", "STEP_ID": step_id, "LOG_PATH": str(step_log_path(step_id))}
    data.setdefault("STATUS", "pending")
    data.setdefault("STEP_ID", step_id)
    data.setdefault("LOG_PATH", str(step_log_path(step_id)))
    return data


def write_step_state(step_id, **values):
    ensure_dirs()
    current = read_step_state(step_id)
    current.update({k: str(v) for k, v in values.items()})
    lines = [f"{k}={env_quote(current[k])}" for k in sorted(current)]
    step_state_path(step_id).write_text("\n".join(lines) + "\n", encoding="utf-8")
    os.chmod(step_state_path(step_id), 0o600)
    return current


def pid_is_running(pid):
    try:
        pid_int = int(pid)
        if pid_int <= 1:
            return False
        os.kill(pid_int, 0)
        return True
    except Exception:
        return False


def normalize_bool(value, default=False):
    if isinstance(value, bool):
        return value
    if value is None:
        return default
    normalized = str(value).strip().lower()
    if normalized in ("1", "true", "yes", "on"):
        return True
    if normalized in ("0", "false", "no", "off"):
        return False
    return default


def technical_access_from_state(state=None):
    current = read_state() if state is None else state
    technical_access = current.get("technical_access")
    if isinstance(technical_access, dict):
        return {
            "configured": normalize_bool(technical_access.get("configured"), False),
            "user": str(technical_access.get("user") or TECHNICAL_ACCESS_USER),
            "ssh_password_auth_enabled": normalize_bool(technical_access.get("ssh_password_auth_enabled"), False),
            "updated_at": str(technical_access.get("updated_at") or ""),
        }
    return {
        "configured": False,
        "user": TECHNICAL_ACCESS_USER,
        "ssh_password_auth_enabled": False,
        "updated_at": "",
    }


def write_report_value(key, value):
    lines = []
    if REPORT_PATH.exists():
        for raw in REPORT_PATH.read_text(encoding="utf-8", errors="replace").splitlines():
            if not raw.startswith(f"{key}="):
                lines.append(raw)
    lines.append(f"{key}={env_quote(value)}")
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")
    os.chmod(REPORT_PATH, 0o600)


def ensure_technical_access_user():
    try:
        subprocess.run(
            ["id", TECHNICAL_ACCESS_USER],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except subprocess.CalledProcessError:
        subprocess.run(
            ["useradd", "-m", "-s", "/bin/bash", "-G", "sudo,adm", TECHNICAL_ACCESS_USER],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

    subprocess.run(
        ["usermod", "-aG", "sudo,adm", TECHNICAL_ACCESS_USER],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    sudoers_path = Path("/etc/sudoers.d/90-fhse-admin")
    sudoers_path.parent.mkdir(parents=True, exist_ok=True)
    sudoers_path.write_text(f"{TECHNICAL_ACCESS_USER} ALL=(ALL) NOPASSWD:ALL\n", encoding="utf-8")
    os.chmod(sudoers_path, 0o440)


def set_system_password(username, password):
    subprocess.run(
        ["chpasswd"],
        input=f"{username}:{password}\n",
        text=True,
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def set_ssh_password_auth(enabled):
    SSH_PASSWORD_CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
    content = "\n".join([
        f"PasswordAuthentication {'yes' if enabled else 'no'}",
        f"KbdInteractiveAuthentication {'yes' if enabled else 'no'}",
        f"ChallengeResponseAuthentication {'yes' if enabled else 'no'}",
        "UsePAM yes",
        "PermitRootLogin no",
        "",
    ])
    SSH_PASSWORD_CONFIG_PATH.write_text(content, encoding="utf-8")
    os.chmod(SSH_PASSWORD_CONFIG_PATH, 0o644)
    for command in (
        ["systemctl", "enable", "ssh"],
        ["systemctl", "restart", "ssh"],
        ["systemctl", "start", "ssh"],
    ):
        subprocess.run(command, check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def write_issue_banner(configured, ssh_password_auth_enabled):
    local_ip = first_local_ip()
    ISSUE_PATH.parent.mkdir(parents=True, exist_ok=True)
    if configured and ssh_password_auth_enabled:
        ssh_line = f"Emergency SSH: {TECHNICAL_ACCESS_USER} / custom password"
    elif configured and not ssh_password_auth_enabled:
        ssh_line = "Emergency SSH: password access disabled"
    else:
        ssh_line = "Emergency SSH: configure in wizard"

    ISSUE_PATH.write_text(
        "\n".join(
            [
                "",
                "FlatCMS Home Server Edition",
                "Open: http://fhse.local:8080",
                f"Fallback: http://{local_ip or 'IP_DU_RASPBERRY'}:8080",
                ssh_line,
                "",
            ]
        ),
        encoding="utf-8",
    )
    os.chmod(ISSUE_PATH, 0o644)


def apply_technical_access(payload):
    state = read_state()
    technical_access = technical_access_from_state(state)
    password = str((payload or {}).get("technical_password") or "")
    confirm = str((payload or {}).get("technical_password_confirm") or "")
    password_provided = password != "" or confirm != ""
    ssh_enabled = normalize_bool(
        (payload or {}).get("enable_ssh_password_auth"),
        technical_access.get("ssh_password_auth_enabled", False),
    )

    if not technical_access["configured"] and not password_provided:
        raise RuntimeError("Définissez d’abord le mot de passe d’accès technique Ubuntu.")

    if password_provided:
        if password != confirm:
            raise RuntimeError("Les deux mots de passe techniques doivent être identiques.")
        if "\n" in password or "\r" in password:
            raise RuntimeError("Le mot de passe technique contient des caractères invalides.")
        if len(password) < MIN_TECHNICAL_PASSWORD_LENGTH:
            raise RuntimeError(
                f"Le mot de passe technique doit contenir au moins {MIN_TECHNICAL_PASSWORD_LENGTH} caractères."
            )
        ensure_technical_access_user()
        set_system_password(TECHNICAL_ACCESS_USER, password)
        technical_access["configured"] = True

    set_ssh_password_auth(ssh_enabled)
    technical_access["user"] = TECHNICAL_ACCESS_USER
    technical_access["ssh_password_auth_enabled"] = ssh_enabled
    technical_access["updated_at"] = now()
    write_issue_banner(technical_access["configured"], ssh_enabled)
    write_state(technical_access=technical_access)
    write_report_value("FHSE_TECHNICAL_ACCESS_USER", TECHNICAL_ACCESS_USER)
    write_report_value("FHSE_SSH_PASSWORD_AUTH", "enabled" if ssh_enabled else "disabled")
    write_report_value("FHSE_TECHNICAL_ACCESS_CONFIGURED", "yes" if technical_access["configured"] else "no")
    return technical_access


def active_runner_pid():
    state = read_state()
    pid = state.get("pid")
    if pid and pid_is_running(pid):
        return int(pid)
    return None


def write_runtime_config(payload):
    ensure_dirs()
    if not BASE_CONFIG.exists():
        raise RuntimeError(f"Missing base config: {BASE_CONFIG}")
    if not PACKAGE_ZIP.exists():
        raise RuntimeError(f"Missing FlatCMS package: {PACKAGE_ZIP}")

    config = {}
    for line in BASE_CONFIG.read_text(encoding="utf-8").splitlines():
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        config[key] = value

    local_ip = payload.get("local_ip") or first_local_ip()
    site_name = payload.get("site_name") or local_ip

    config.update(
        {
            "FLATCMS_PROFILE": payload.get("profile", "mini-pc") or "mini-pc",
            "FLATCMS_SERVER_NAME": payload.get("server_name", "fhse"),
            "FLATCMS_TECHNICAL_ACCESS_USER": TECHNICAL_ACCESS_USER,
            "FLATCMS_SSH_PASSWORD_AUTH": "1" if normalize_bool(payload.get("enable_ssh_password_auth"), False) else "0",
            "FLATCMS_ACCESS_MODE": "local_only",
            "FLATCMS_SITE_NAME": site_name,
            "FLATCMS_PACKAGE_ZIP": str(PACKAGE_ZIP),
            "FLATCMS_INSTALL_PURE_FTPD": "0",
            "FLATCMS_CREATE_AAPANEL_SITE": "1",
            "FHS_RESET_LOGS_ON_START": "0",
        }
    )

    lines = ["# Generated by FlatCMS Home Server Installer", f"# Generated at {now()}", ""]
    for key in sorted(config):
        lines.append(f"{key}={env_quote(config[key])}")
    RUNTIME_CONFIG.write_text("\n".join(lines) + "\n", encoding="utf-8")
    os.chmod(RUNTIME_CONFIG, 0o600)
    write_state(runtime_config=str(RUNTIME_CONFIG))
    return RUNTIME_CONFIG


def reset_run_files():
    ensure_dirs()
    for path in STEP_STATE_DIR.glob("*.env"):
        try:
            path.unlink()
        except Exception:
            pass
    for path in STEP_LOG_DIR.glob("*.log"):
        try:
            path.unlink()
        except Exception:
            pass
    INSTALL_LOG.write_text("", encoding="utf-8")
    REPORT_PATH.write_text("", encoding="utf-8")
    write_state(status="idle", message="Assistant prêt", active_step="", pid=None, started_at="", finished_at="")


def completed_from_report(step_id, report):
    if step_id == "system":
        return report.get("FHS_BASE_PACKAGES") == "installed"
    if step_id == "panel":
        return report.get("AAPANEL_STATUS") == "installed"
    if step_id == "nginx":
        return report.get("AAPANEL_NGINX_STATUS") == "installed" or report.get("CHECK_NGINX") == "ok"
    if step_id == "php":
        return (report.get("AAPANEL_PHP_STATUS") == "installed" or report.get("CHECK_PHP85") == "ok") and report.get("CHECK_PHP85_FILEINFO") in ("ok", "enabled")
    if step_id == "site":
        return report.get("AAPANEL_SITE_STATUS") in ("official", "manual-vhost")
    if step_id == "flatcms":
        return report.get("FLATCMS_STATUS") in ("package-deployed", "placeholder-ready")
    if step_id == "checks":
        return report.get("CHECK_HTTP_LOCAL") == "ok" and report.get("CHECK_FLATCMS_ROUTE") == "ok"
    return False


def sync_state():
    state = read_state()
    pid = state.get("pid")
    if state.get("status") == "running" and pid and not pid_is_running(pid):
        active = state.get("active_step", "")
        step = read_step_state(active) if active else {}
        if step.get("STATUS") == "running":
            write_step_state(active, STATUS="failed", FINISHED_AT=now(), EXIT_CODE="1", MESSAGE="Étape interrompue")
        state = write_state(status="failed", message="Étape interrompue", pid=None, finished_at=now())
    return state


def build_steps(report, state):
    active = state.get("active_step") if state.get("status") == "running" else ""
    items = []
    for step in PRODUCT_STEPS:
        sid = step["id"]
        sstate = read_step_state(sid)
        status = sstate.get("STATUS", "pending")
        if completed_from_report(sid, report) and status not in ("running", "failed"):
            status = "success"
        if sid == active:
            status = "running"
        items.append({
            **{k: v for k, v in step.items() if k != "scripts"},
            "status": status,
            "log_path": sstate.get("LOG_PATH", str(step_log_path(sid))),
            "started_at": sstate.get("STARTED_AT", ""),
            "finished_at": sstate.get("FINISHED_AT", ""),
            "exit_code": sstate.get("EXIT_CODE", ""),
            "message": sstate.get("MESSAGE", ""),
        })
    return items


def progress_from_steps(steps):
    done = len([s for s in steps if s["status"] == "success"])
    running = 0.35 if any(s["status"] == "running" for s in steps) else 0
    return min(100, round(((done + running) / len(steps)) * 100))


def next_pending_step(steps):
    for step in steps:
        if step["status"] == "running":
            return step
    for step in steps:
        if step["status"] != "success":
            return step
    return steps[-1]


def build_configuration(report, credentials):
    local_ip = first_local_ip()
    technical_access = technical_access_from_state()
    aapanel_context = aapanel_backend_context(credentials, report)
    aapanel_direct_url = aapanel_context.get("backend_url", "")
    return {
        "flatcms_url": report.get("FLATCMS_PRIMARY_URL") or report.get("FLATCMS_MDNS_URL") or "http://fhse.local/",
        "flatcms_fallback_url": report.get("FLATCMS_LOCAL_URL") or f"http://{local_ip}/",
        "aapanel_url": aapanel_direct_url,
        "aapanel_direct_url": aapanel_direct_url,
        "aapanel_username": credentials.get("AAPANEL_USERNAME", ""),
        "aapanel_password": credentials.get("AAPANEL_PASSWORD", ""),
        "php_ini": "/www/server/php/85/etc/php.ini",
        "public_root": report.get("FLATCMS_PUBLIC_ROOT", "/www/wwwroot/default/public"),
        "vhost": report.get("FLATCMS_VHOST", ""),
        "rewrite": report.get("FLATCMS_REWRITE", ""),
        "credentials_file": str(CREDENTIALS_PATH) if CREDENTIALS_PATH.exists() else "",
        "report_file": str(REPORT_PATH),
        "technical_access_user": technical_access.get("user", TECHNICAL_ACCESS_USER),
        "technical_access_ready": technical_access.get("configured", False),
        "ssh_password_auth_enabled": technical_access.get("ssh_password_auth_enabled", False),
    }


def product_payload():
    state = sync_state()
    report = read_env_file(REPORT_PATH)
    credentials = refresh_credentials()
    steps = build_steps(report, state)
    active = next_pending_step(steps)
    all_done = all(s["status"] == "success" for s in steps)

    if all_done:
        headline = "Votre serveur FlatCMS est opérationnel"
    elif state.get("status") == "running":
        headline = active.get("headline", "Installation en cours")
    else:
        headline = "Installation guidée étape par étape"

    return {
        **state,
        "headline": headline,
        "local_ip": first_local_ip(),
        "steps": steps,
        "progress": progress_from_steps(steps),
        "current_step": active,
        "report": report,
        "configuration": build_configuration(report, credentials),
        "technical_access": technical_access_from_state(state),
    }


def write_step_runner(step_id, runtime_config):
    step = STEP_MAP[step_id]
    scripts = [INSTALLER_DIR / "installer" / script for script in step["scripts"]]
    for script in scripts:
        if not script.exists():
            raise RuntimeError(f"Missing step script: {script}")

    log_path = step_log_path(step_id)
    state_path = step_state_path(step_id)
    profile = "${FLATCMS_PROFILE:-mini-pc}"
    runner_path = RUNNER_DIR / f"run-{step_id}.sh"

    script_lines = "\n".join([f"bash {shell_quote(script)}" for script in scripts])
    runner = f"""#!/usr/bin/env bash
set +e
STEP_ID={shell_quote(step_id)}
STEP_TITLE={shell_quote(step['title'])}
STATE_PATH={shell_quote(state_path)}
GLOBAL_STATE_PATH={shell_quote(STATE_PATH)}
LOG_PATH={shell_quote(log_path)}
RUNTIME_CONFIG={shell_quote(runtime_config)}
INSTALLER_DIR={shell_quote(INSTALLER_DIR / 'installer')}
mkdir -p "$(dirname "$STATE_PATH")" "$(dirname "$GLOBAL_STATE_PATH")" "$(dirname "$LOG_PATH")"
write_step_state() {{
  local status="$1"
  local exit_code="${{2:-}}"
  local message="${{3:-}}"
  {{
    printf 'STEP_ID=%q\n' "$STEP_ID"
    printf 'TITLE=%q\n' "$STEP_TITLE"
    printf 'STATUS=%q\n' "$status"
    printf 'STARTED_AT=%q\n' "$STARTED_AT"
    printf 'FINISHED_AT=%q\n' "$(date -Is)"
    printf 'EXIT_CODE=%q\n' "$exit_code"
    printf 'MESSAGE=%q\n' "$message"
    printf 'LOG_PATH=%q\n' "$LOG_PATH"
  }} > "$STATE_PATH"
  chmod 600 "$STATE_PATH" 2>/dev/null || true
}}
update_global_state() {{
  local status="$1"
  local message="$2"
  python3 - "$GLOBAL_STATE_PATH" "$status" "$message" <<'PY_STATE'
import json, sys, time
path, status, message = sys.argv[1], sys.argv[2], sys.argv[3]
def now(): return time.strftime('%Y-%m-%dT%H:%M:%S%z')
try:
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)
except Exception:
    data = {{}}
data.update({{'status': status, 'message': message, 'pid': None, 'finished_at': now()}})
with open(path, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
PY_STATE
}}
STARTED_AT="$(date -Is)"
{{
  printf '\n[%s] Starting FlatCMS step: %s\n' "$(date -Is)" "$STEP_TITLE"
  set -a
  [ -f "$RUNTIME_CONFIG" ] && source "$RUNTIME_CONFIG"
  PROFILE_FILE="$INSTALLER_DIR/profiles/{profile}.profile"
  [ -f "$PROFILE_FILE" ] && source "$PROFILE_FILE"
  set +a
  export FHS_RESET_LOGS_ON_START=0
  {script_lines}
  EXIT_CODE=$?
  if [ "$EXIT_CODE" -eq 0 ]; then
    printf '[%s] FlatCMS step succeeded: %s\n' "$(date -Is)" "$STEP_TITLE"
    write_step_state success 0 "Étape réussie"
    update_global_state idle "Étape réussie"
  else
    printf '[%s] FlatCMS step failed: %s / exit %s\n' "$(date -Is)" "$STEP_TITLE" "$EXIT_CODE"
    write_step_state failed "$EXIT_CODE" "Étape en erreur"
    update_global_state failed "Étape en erreur"
  fi
}} >> "$LOG_PATH" 2>&1
exit 0
"""
    runner_path.write_text(runner, encoding="utf-8")
    os.chmod(runner_path, 0o700)
    return runner_path


def start_step(step_id, payload):
    if step_id not in STEP_MAP:
        raise RuntimeError("Étape inconnue")
    if active_runner_pid():
        raise RuntimeError("Une étape est déjà en cours")

    if step_id == "system":
        reset_run_files()
    runtime_config = write_runtime_config(payload or {})
    log_path = step_log_path(step_id)
    log_path.write_text("", encoding="utf-8")
    write_step_state(step_id, STATUS="running", STARTED_AT=now(), FINISHED_AT="", EXIT_CODE="", MESSAGE="Étape en cours", LOG_PATH=str(log_path))
    write_state(status="running", message="Étape en cours", active_step=step_id, started_at=now(), finished_at="", pid=None, runtime_config=str(runtime_config))

    runner = write_step_runner(step_id, runtime_config)
    command = f"nohup bash {shell_quote(runner)} >/dev/null 2>&1 </dev/null & echo $!"
    output = subprocess.check_output(["bash", "-c", command], cwd=str(BUNDLE_DIR), text=True).strip()
    pid = int(output.splitlines()[-1])
    write_state(pid=pid)
    return pid


class Handler(BaseHTTPRequestHandler):
    server_version = "FlatCMSInstaller/0.18.2-rc3.13"

    def log_message(self, fmt, *args):
        return

    def send_json(self, payload, status=200):
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        try:
            self.wfile.write(data)
        except BrokenPipeError:
            pass

    def send_text(self, text, content_type="text/plain; charset=utf-8", status=200):
        data = text.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        try:
            self.wfile.write(data)
        except BrokenPipeError:
            pass

    def read_json_body(self):
        length = int(self.headers.get("Content-Length", "0"))
        if length <= 0:
            return {}
        raw = self.rfile.read(length).decode("utf-8")
        return json.loads(raw) if raw.strip() else {}

    def require_loopback(self):
        if is_loopback_address(self.client_address[0]):
            return True

        self.send_json({
            "ok": False,
            "error": "fhse_api_loopback_only",
        }, 403)
        return False

    def do_HEAD(self):
        path = urlparse(self.path).path
        if path.startswith("/api/"):
            known_paths = (
                "/api/status",
                "/api/log",
                "/api/report",
                "/api/credentials",
                "/api/fhse/capabilities",
                "/api/fhse/cloudflare/tunnel/status",
                "/api/fhse/cloudflare/tunnel/configure",
                "/api/fhse/cloudflare/tunnel/enable",
                "/api/fhse/cloudflare/tunnel/disable",
                "/api/fhse/cloudflare/tunnel/restart",
            )
            self.send_response(200 if path in known_paths else 404)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.end_headers()
            return
        if path == "/":
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            return
        self.send_response(404)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.end_headers()

    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/api/status":
            self.send_json(product_payload())
            return
        if path == "/api/log":
            step_id = urlparse(self.path).query.replace("step=", "").strip()
            if step_id in STEP_MAP:
                self.send_json({"step": step_id, "log": read_text(step_log_path(step_id), 80000)})
            else:
                self.send_json({"log": read_text(INSTALL_LOG, 80000)})
            return
        if path == "/api/report":
            self.send_json({"report": read_env_file(REPORT_PATH), "raw": read_text(REPORT_PATH, 80000)})
            return
        if path == "/api/credentials":
            self.send_json(refresh_credentials())
            return
        if path == "/api/fhse/capabilities":
            if not self.require_loopback():
                return
            self.send_json({"ok": True, "capabilities": current_capabilities(enforce_guard=True)})
            return
        if path == "/api/fhse/cloudflare/tunnel/status":
            if not self.require_loopback():
                return
            self.send_json({"ok": True, **tunnel_status()})
            return
        if path == "/":
            self.send_text(INDEX_HTML.read_text(encoding="utf-8"), "text/html; charset=utf-8")
            return
        self.send_json({"error": "Not found"}, 404)

    def do_POST(self):
        path = urlparse(self.path).path
        try:
            payload = self.read_json_body()
            if path == "/api/configure":
                apply_technical_access(payload or {})
                runtime = write_runtime_config(payload or {})
                self.send_json({"ok": True, "runtime_config": str(runtime), "status": product_payload()})
                return
            if path == "/api/run-step":
                step_id = payload.get("step_id", "")
                cfg = payload.get("config", {}) or {}
                apply_technical_access(cfg)
                pid = start_step(step_id, cfg)
                self.send_json({"ok": True, "pid": pid, "step_id": step_id, "status": product_payload()})
                return
            if path == "/api/reset":
                if active_runner_pid():
                    raise RuntimeError("Impossible de réinitialiser pendant une étape en cours")
                reset_run_files()
                self.send_json({"ok": True, "status": product_payload()})
                return
            if path == "/api/fhse/cloudflare/tunnel/configure":
                if not self.require_loopback():
                    return
                self.send_json({"ok": True, **configure_tunnel(payload or {})})
                return
            if path == "/api/fhse/cloudflare/tunnel/enable":
                if not self.require_loopback():
                    return
                self.send_json({"ok": True, **enable_tunnel(payload or {})})
                return
            if path == "/api/fhse/cloudflare/tunnel/disable":
                if not self.require_loopback():
                    return
                self.send_json({"ok": True, **disable_tunnel()})
                return
            if path == "/api/fhse/cloudflare/tunnel/restart":
                if not self.require_loopback():
                    return
                self.send_json({"ok": True, **restart_tunnel(payload or {})})
                return
            self.send_json({"error": "Not found"}, 404)
        except FhseApiError as exc:
            self.send_json({"ok": False, "error": exc.code, "details": exc.details}, exc.status)
        except Exception as exc:
            self.send_json({"ok": False, "error": str(exc), "status": product_payload()}, 500)

    def do_PUT(self):
        self.send_json({"error": "Not found"}, 404)

    def do_PATCH(self):
        self.send_json({"error": "Not found"}, 404)

    def do_DELETE(self):
        self.send_json({"error": "Not found"}, 404)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8080)
    args = parser.parse_args()
    ensure_dirs()
    httpd = ThreadingHTTPServer((args.host, args.port), Handler)

    def stop(signum, frame):
        import threading
        threading.Thread(target=httpd.shutdown, daemon=True).start()

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    print(f"FlatCMS Installer step-by-step listening on http://{args.host}:{args.port}")
    httpd.serve_forever()


if __name__ == "__main__":
    main()
