#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

if [ "${FLATCMS_INSTALL_FLATCMS:-1}" != "1" ]; then
  log "FlatCMS installation disabled by configuration."
  write_report_value "FLATCMS_STATUS" "skipped"
  exit 0
fi

WEB_ROOT="${FLATCMS_WEB_ROOT:-/www/wwwroot/default}"
PUBLIC_ROOT="${FLATCMS_PUBLIC_ROOT:-$WEB_ROOT/public}"
PACKAGE_ZIP="${FLATCMS_PACKAGE_ZIP:-}"
WEB_USER="${FLATCMS_WEB_USER:-www}"
WEB_GROUP="${FLATCMS_WEB_GROUP:-www}"
LOCAL_IP="$(detect_local_ipv4)"
SITE_NAME="${FLATCMS_SITE_NAME:-$LOCAL_IP}"
VHOST_SAFE_NAME="$(printf '%s' "$SITE_NAME" | tr -c 'A-Za-z0-9._-' '_')"
AAPANEL_VHOST_DIR="/www/server/panel/vhost/nginx"
AAPANEL_REWRITE_DIR="/www/server/panel/vhost/rewrite"
FLATCMS_VHOST="$AAPANEL_VHOST_DIR/${VHOST_SAFE_NAME}.conf"
FLATCMS_REWRITE="$AAPANEL_REWRITE_DIR/${VHOST_SAFE_NAME}.conf"

copy_tree_into_webroot() {
  local source_dir="$1"
  mkdir -p "$WEB_ROOT"
  # Important: keep /www/wwwroot/default itself in place.
  # aaPanel binds its Website record to this path; moving it breaks routing.
  (shopt -s dotglob nullglob && cp -a "$source_dir"/* "$WEB_ROOT"/)
}

if [ -n "$PACKAGE_ZIP" ] && [ -f "$PACKAGE_ZIP" ]; then
  log "Deploying FlatCMS package from: $PACKAGE_ZIP"
  mkdir -p "$WEB_ROOT" "$PUBLIC_ROOT"
  TMP_EXTRACT="$(mktemp -d)"
  unzip -q "$PACKAGE_ZIP" -d "$TMP_EXTRACT"
  if [ -d "$TMP_EXTRACT/FlatCMS-main/public" ]; then
    copy_tree_into_webroot "$TMP_EXTRACT/FlatCMS-main"
  elif [ "$(find "$TMP_EXTRACT" -mindepth 1 -maxdepth 1 -type d | wc -l)" = "1" ] && [ -d "$(find "$TMP_EXTRACT" -mindepth 1 -maxdepth 1 -type d -print -quit)/public" ]; then
    FIRST_DIR="$(find "$TMP_EXTRACT" -mindepth 1 -maxdepth 1 -type d -print -quit)"
    copy_tree_into_webroot "$FIRST_DIR"
  else
    copy_tree_into_webroot "$TMP_EXTRACT"
  fi
  rm -rf "$TMP_EXTRACT"

  # aaPanel may create a default HTML file. FlatCMS must be served by index.php.
  if [ -f "$PUBLIC_ROOT/index.php" ] && [ -f "$PUBLIC_ROOT/index.html" ]; then
    rm -f "$PUBLIC_ROOT/index.html"
  fi
else
  log "No FlatCMS package zip configured. Preparing placeholder web root: $PUBLIC_ROOT"
  mkdir -p "$PUBLIC_ROOT"
  cat > "$PUBLIC_ROOT/index.html" <<'HTML'
<!doctype html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>FlatCMS Home Server</title>
  <style>
    body { margin: 0; font-family: system-ui, sans-serif; background: #0d121c; color: #fff; display: grid; min-height: 100vh; place-items: center; }
    main { max-width: 760px; padding: 40px; text-align: center; }
    h1 { color: #818cf8; }
  </style>
</head>
<body>
  <main>
    <h1>FlatCMS Home Server Edition</h1>
    <p>Le serveur web fonctionne. Le déploiement FlatCMS réel viendra remplacer cette page.</p>
  </main>
</body>
</html>
HTML
fi

if [ -f "$WEB_ROOT/.env.example" ] && [ ! -f "$WEB_ROOT/.env.local" ]; then
  log "Creating .env.local from .env.example."
  cp "$WEB_ROOT/.env.example" "$WEB_ROOT/.env.local"
  sed -i "s#^APP_ENV=.*#APP_ENV=production#" "$WEB_ROOT/.env.local" || true
  sed -i "s#^APP_DEBUG=.*#APP_DEBUG=false#" "$WEB_ROOT/.env.local" || true
  sed -i "s#^APP_URL=.*#APP_URL=http://fhse.local#" "$WEB_ROOT/.env.local" || true
fi

if id "$WEB_USER" >/dev/null 2>&1 && getent group "$WEB_GROUP" >/dev/null 2>&1; then
  chown -R "$WEB_USER:$WEB_GROUP" "$WEB_ROOT" 2>/dev/null || true
else
  chown -R www-data:www-data "$WEB_ROOT" 2>/dev/null || true
fi

for user_ini in "$WEB_ROOT/.user.ini" "$PUBLIC_ROOT/.user.ini"; do
  if [ -e "$user_ini" ]; then
    chattr -i "$user_ini" 2>/dev/null || true
    rm -f "$user_ini"
  fi
done

PHP_FASTCGI_PASS="${FLATCMS_PHP_FASTCGI_PASS:-}"
if [ -z "$PHP_FASTCGI_PASS" ]; then
  for candidate in \
    "unix:/tmp/php-cgi-85.sock" \
    "unix:/www/server/php/85/var/run/php-fpm.sock" \
    "unix:/run/php/php8.5-fpm.sock"; do
    case "$candidate" in
      unix:*)
        socket_path="${candidate#unix:}"
        if [ -S "$socket_path" ]; then
          PHP_FASTCGI_PASS="$candidate"
          break
        fi
        ;;
      *)
        PHP_FASTCGI_PASS="$candidate"
        ;;
    esac
  done
fi

if [ -x /www/server/nginx/sbin/nginx ]; then
  /www/server/nginx/sbin/nginx -t
  /etc/init.d/nginx reload 2>/dev/null \
    || service nginx reload 2>/dev/null \
    || /www/server/nginx/sbin/nginx -s reload 2>/dev/null \
    || true
fi

if [ -n "$PACKAGE_ZIP" ] && [ -f "$PACKAGE_ZIP" ]; then
  write_report_value "FLATCMS_STATUS" "package-deployed"
else
  write_report_value "FLATCMS_STATUS" "placeholder-ready"
fi
write_report_value "FLATCMS_LOCAL_URL" "http://${LOCAL_IP}/"
write_report_value "FLATCMS_MDNS_URL" "http://fhse.local/"
write_report_value "FLATCMS_PRIMARY_URL" "http://fhse.local/"
write_report_value "FLATCMS_SITE_NAME" "$SITE_NAME"
write_report_value "FLATCMS_PUBLIC_ROOT" "$PUBLIC_ROOT"
write_report_value "FLATCMS_PHP_FASTCGI_PASS" "$PHP_FASTCGI_PASS"
write_report_value "FLATCMS_WEB_USER" "$WEB_USER"
write_report_value "FLATCMS_WEB_GROUP" "$WEB_GROUP"
write_report_value "FLATCMS_VHOST" "$FLATCMS_VHOST"
write_report_value "FLATCMS_REWRITE" "$FLATCMS_REWRITE"
