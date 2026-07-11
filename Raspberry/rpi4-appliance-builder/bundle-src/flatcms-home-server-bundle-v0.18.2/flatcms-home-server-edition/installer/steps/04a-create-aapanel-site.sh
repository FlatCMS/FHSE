#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

WEB_ROOT="${FLATCMS_WEB_ROOT:-/www/wwwroot/default}"
PUBLIC_ROOT="${FLATCMS_PUBLIC_ROOT:-$WEB_ROOT/public}"
REQUIRE_AAPANEL_STACK="${FLATCMS_REQUIRE_AAPANEL_STACK:-1}"
LOCAL_IP="$(detect_local_ipv4)"
AAPANEL_NGINX_BIN="/www/server/nginx/sbin/nginx"
AAPANEL_VHOST_DIR="/www/server/panel/vhost/nginx"
AAPANEL_PHP85_BIN="/www/server/php/85/bin/php"
SITE_NAME="${FLATCMS_SITE_NAME:-$LOCAL_IP}"
# FHSE must be reachable by local IP, mDNS hostname, short hostname,
# and as the local default vhost. This prevents aaPanel's fallback
# page from answering instead of FlatCMS.
SERVER_NAMES="$SITE_NAME"
for name in "$LOCAL_IP" "fhse.local" "fhse" "_"; do
  if [ -n "$name" ] && ! printf ' %s ' "$SERVER_NAMES" | grep -Fq " $name "; then
    SERVER_NAMES="$SERVER_NAMES $name"
  fi
done
VHOST_SAFE_NAME="$(printf '%s' "$SITE_NAME" | tr -c 'A-Za-z0-9._-' '_')"
FLATCMS_VHOST="$AAPANEL_VHOST_DIR/${VHOST_SAFE_NAME}.conf"
AAPANEL_REWRITE_DIR="/www/server/panel/vhost/rewrite"
FLATCMS_REWRITE="$AAPANEL_REWRITE_DIR/${VHOST_SAFE_NAME}.conf"
CREATE_AAPANEL_SITE="${FLATCMS_CREATE_AAPANEL_SITE:-1}"
PHP_VERSION="${FLATCMS_PHP_VERSION:-8.5}"
PHP_SHORT="${PHP_VERSION/./}"

reload_aapanel_nginx() {
  "$AAPANEL_NGINX_BIN" -t
  /etc/init.d/nginx reload 2>/dev/null \
    || service nginx reload 2>/dev/null \
    || "$AAPANEL_NGINX_BIN" -s reload 2>/dev/null \
    || /etc/init.d/nginx restart 2>/dev/null \
    || service nginx restart 2>/dev/null \
    || true
}

reload_aapanel_php() {
  /etc/init.d/php-fpm-"$PHP_SHORT" reload 2>/dev/null \
    || service php-fpm-"$PHP_SHORT" reload 2>/dev/null \
    || /etc/init.d/php-fpm-"$PHP_SHORT" restart 2>/dev/null \
    || service php-fpm-"$PHP_SHORT" restart 2>/dev/null \
    || true
}

if [ "${FLATCMS_INSTALL_FLATCMS:-1}" != "1" ]; then
  log "FlatCMS installation disabled by configuration."
  write_report_value "AAPANEL_SITE_STATUS" "skipped"
  exit 0
fi

if [ "$REQUIRE_AAPANEL_STACK" = "1" ]; then
  [ -x "$AAPANEL_NGINX_BIN" ] || fail "aaPanel Nginx is missing. Install Nginx 1.24 before creating the FlatCMS site."
  [ -x "$AAPANEL_PHP85_BIN" ] || fail "aaPanel PHP 8.5 is missing. Install PHP 8.5 before creating the FlatCMS site."
fi

mkdir -p "$PUBLIC_ROOT"

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

if [ "$REQUIRE_AAPANEL_STACK" = "1" ] && [ -z "$PHP_FASTCGI_PASS" ]; then
  fail "Could not find the aaPanel PHP 8.5 FPM socket. Expected /tmp/php-cgi-85.sock."
fi

if [ -x "$AAPANEL_NGINX_BIN" ] && [ -d "$AAPANEL_VHOST_DIR" ]; then
  log "Preparing aaPanel site for FlatCMS."
  AAPANEL_SITE_STATUS="manual-vhost"

  if [ "$CREATE_AAPANEL_SITE" = "1" ] && [ -f "$SCRIPT_DIR/lib/aapanel_create_site.py" ]; then
    AAPANEL_PYTHON="/www/server/panel/pyenv/bin/python3"
    [ -x "$AAPANEL_PYTHON" ] || AAPANEL_PYTHON="$(command -v python3 || true)"
    if [ -n "$AAPANEL_PYTHON" ]; then
      log "Trying official aaPanel Website creation for: $SITE_NAME"
      SITE_CREATE_OUTPUT="$("$AAPANEL_PYTHON" "$SCRIPT_DIR/lib/aapanel_create_site.py" "$SITE_NAME" "$WEB_ROOT" "$PHP_SHORT" "/public" "FlatCMS Home Server" 2>&1)" || true
      log "aaPanel Website creation result: $SITE_CREATE_OUTPUT"
      if printf '%s' "$SITE_CREATE_OUTPUT" | grep -Eq '"status": "(created|exists)"'; then
        AAPANEL_SITE_STATUS="official"
      else
        log "aaPanel Website creation failed; continuing with generated vhost fallback."
      fi
    fi
  fi

  for old_flatcms_vhost in \
    "$AAPANEL_VHOST_DIR/00-flatcms-home-server.conf" \
    "$AAPANEL_VHOST_DIR/000-flatcms-home-server.conf"; do
    if [ -f "$old_flatcms_vhost" ]; then
      rm -f "$old_flatcms_vhost"
    fi
  done

  mkdir -p "$AAPANEL_REWRITE_DIR"
  cat > "$FLATCMS_REWRITE" <<'NGINX'
location /{
    if (!-e $request_filename) {
       rewrite  ^(.*)$  /index.php/$1  last;
       break;
    }
}
NGINX

  log "Configuring aaPanel virtual host for FlatCMS: $SITE_NAME"
  cat > "$FLATCMS_VHOST" <<NGINX
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name ${SERVER_NAMES};
    root ${PUBLIC_ROOT};
    index index.php index.html;
    server_tokens off;

    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    include ${FLATCMS_REWRITE};

    location = /index.php {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT \$realpath_root;
        fastcgi_param PHP_ADMIN_VALUE "open_basedir=${WEB_ROOT}/:/tmp/";
        fastcgi_pass ${PHP_FASTCGI_PASS};
    }

    location ~ ^(.+\.php)(/.+)\$ {
        include fastcgi_params;
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT \$realpath_root;
        fastcgi_param PHP_ADMIN_VALUE "open_basedir=${WEB_ROOT}/:/tmp/";
        fastcgi_pass ${PHP_FASTCGI_PASS};
    }

    location ~ \.php\$ {
        return 404;
    }

    location ~* (^|/)\.(?!well-known/) {
        deny all;
    }

    location ~* ^/(data|storage|config|app|resources|vendor)/ {
        deny all;
    }
}
NGINX

  reload_aapanel_nginx
  reload_aapanel_php

  if [ -n "$LOCAL_IP" ]; then
    log "Local binding configured for: $LOCAL_IP"
  fi
else
  fail "No supported aaPanel Nginx runtime was found."
fi

write_report_value "AAPANEL_SITE_STATUS" "$AAPANEL_SITE_STATUS"
write_report_value "FLATCMS_LOCAL_URL" "http://${LOCAL_IP}/"
write_report_value "FLATCMS_MDNS_URL" "http://fhse.local/"
write_report_value "FLATCMS_PRIMARY_URL" "http://fhse.local/"
write_report_value "FLATCMS_SITE_NAME" "$SITE_NAME"
write_report_value "FLATCMS_PUBLIC_ROOT" "$PUBLIC_ROOT"
write_report_value "FLATCMS_PHP_FASTCGI_PASS" "$PHP_FASTCGI_PASS"
write_report_value "FLATCMS_VHOST" "$FLATCMS_VHOST"
write_report_value "FLATCMS_REWRITE" "$FLATCMS_REWRITE"
