#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

log "Running final healthcheck."

if systemctl is-active --quiet ssh; then
  write_report_value "CHECK_SSH" "ok"
else
  write_report_value "CHECK_SSH" "failed"
fi

if command -v bt >/dev/null 2>&1; then
  write_report_value "CHECK_AAPANEL" "installed"
else
  write_report_value "CHECK_AAPANEL" "missing"
fi

if [ -x /www/server/nginx/sbin/nginx ]; then
  NGINX_VERSION="$(/www/server/nginx/sbin/nginx -v 2>&1 | sed 's#nginx version: ##')"
  write_report_value "CHECK_NGINX" "ok"
  write_report_value "CHECK_NGINX_VERSION" "$NGINX_VERSION"
elif systemctl is-active --quiet nginx || service nginx status >/dev/null 2>&1; then
  write_report_value "CHECK_NGINX" "ubuntu-fallback"
else
  write_report_value "CHECK_NGINX" "failed"
fi

if [ -S /tmp/php-cgi-85.sock ] && [ -x /www/server/php/85/bin/php ]; then
  PHP85_VERSION="$(/www/server/php/85/bin/php -v | head -1)"
  write_report_value "CHECK_PHP85" "ok"
  write_report_value "CHECK_PHP85_VERSION" "$PHP85_VERSION"
  write_report_value "CHECK_PHP85_SOCKET" "/tmp/php-cgi-85.sock"
  if /www/server/php/85/bin/php -m 2>/dev/null | grep -qi '^fileinfo$'; then
    write_report_value "CHECK_PHP85_FILEINFO" "ok"
  else
    write_report_value "CHECK_PHP85_FILEINFO" "missing"
  fi
elif systemctl is-active --quiet php-fpm-85 || service php-fpm-85 status >/dev/null 2>&1; then
  write_report_value "CHECK_PHP85" "service-ok"
else
  write_report_value "CHECK_PHP85" "unknown"
fi

if [ "${FLATCMS_INSTALL_PURE_FTPD:-0}" = "1" ] && [ -d /www/server/pure-ftpd ]; then
  write_report_value "CHECK_PURE_FTPD" "installed"
elif [ "${FLATCMS_INSTALL_PURE_FTPD:-0}" = "1" ] && (systemctl is-active --quiet pure-ftpd || service pure-ftpd status >/dev/null 2>&1); then
  write_report_value "CHECK_PURE_FTPD" "ok"
else
  write_report_value "CHECK_PURE_FTPD" "skipped"
fi

LOCAL_IP="$(detect_local_ipv4)"
HTTP_URL="http://127.0.0.1/"
HTTP_HEADERS="$(mktemp)"
HTTP_BODY="$(mktemp)"
FLATCMS_ROUTE_STATUS="unknown"
FLATCMS_MDNS_ROUTE_STATUS="unknown"
FLATCMS_DOMAIN_ROUTE_STATUS="skipped"

check_flatcms_host() {
  local host="$1"
  local body_file="$2"
  if curl -fsS -H "Host: ${host}" "$HTTP_URL" > "$body_file" 2>/dev/null; then
    if grep -Eqi "flatcms_session|FlatCMS|Installation" "$body_file" \
      && ! grep -Eqi "Website not found|domain name has been bound|website has been stopped" "$body_file"; then
      return 0
    fi
  fi
  return 1
}

if curl -fsSI -H "Host: ${LOCAL_IP}" "$HTTP_URL" > "$HTTP_HEADERS" 2>/dev/null; then
  write_report_value "CHECK_HTTP_LOCAL" "ok"
else
  write_report_value "CHECK_HTTP_LOCAL" "failed"
fi

if curl -fsSI -H "Host: fhse.local" "$HTTP_URL" > "$HTTP_HEADERS" 2>/dev/null; then
  write_report_value "CHECK_HTTP_MDNS" "ok"
else
  write_report_value "CHECK_HTTP_MDNS" "failed"
fi

for _ in $(seq 1 6); do
  if check_flatcms_host "$LOCAL_IP" "$HTTP_BODY"; then
    FLATCMS_ROUTE_STATUS="ok"
    break
  fi
  sleep 2
done

for _ in $(seq 1 6); do
  if check_flatcms_host "fhse.local" "$HTTP_BODY"; then
    FLATCMS_MDNS_ROUTE_STATUS="ok"
    break
  fi
  sleep 2
done

write_report_value "CHECK_FLATCMS_ROUTE" "$FLATCMS_ROUTE_STATUS"
write_report_value "CHECK_FLATCMS_MDNS_ROUTE" "$FLATCMS_MDNS_ROUTE_STATUS"

if [ -n "${FLATCMS_DOMAIN:-}" ]; then
  DOMAIN_HOST="$(printf '%s' "$FLATCMS_DOMAIN" | sed 's#^https\?://##;s#/*$##')"
  for _ in $(seq 1 6); do
    if check_flatcms_host "$DOMAIN_HOST" "$HTTP_BODY"; then
      FLATCMS_DOMAIN_ROUTE_STATUS="ok"
      break
    fi
    sleep 2
  done
fi
write_report_value "CHECK_FLATCMS_DOMAIN_ROUTE" "$FLATCMS_DOMAIN_ROUTE_STATUS"

if curl -fsS "http://127.0.0.1/" >/dev/null 2>&1; then
  write_report_value "CHECK_HTTP_LOOPBACK" "ok"
else
  write_report_value "CHECK_HTTP_LOOPBACK" "failed"
fi

rm -f "$HTTP_HEADERS" "$HTTP_BODY"

if [ "$FLATCMS_ROUTE_STATUS" != "ok" ]; then
  fail "FlatCMS local route is not reachable through Host: ${LOCAL_IP}. aaPanel binding or vhost routing is not aligned."
fi

if [ "$FLATCMS_MDNS_ROUTE_STATUS" != "ok" ]; then
  fail "FlatCMS mDNS route is not reachable through Host: fhse.local. aaPanel binding or vhost routing is not aligned."
fi

if [ "${FLATCMS_ACCESS_MODE:-local_only}" = "cloudflare_tunnel" ]; then
  if ! grep -q "^CLOUDFLARE_TUNNEL_STATUS=active$" "$FHS_REPORT_PATH" 2>/dev/null; then
    fail "Cloudflare Tunnel is not active."
  fi

  if [ -n "${FLATCMS_DOMAIN:-}" ] && [ "$FLATCMS_DOMAIN_ROUTE_STATUS" != "ok" ]; then
    fail "FlatCMS domain host route is not reachable locally through Host: ${FLATCMS_DOMAIN}."
  fi
fi

log "Final healthcheck completed."
