#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

INSTALL_STACK="${FLATCMS_INSTALL_AAPANEL_STACK:-1}"
INSTALL_DIR="/www/server/panel/install"
INSTALL_SOFT="$INSTALL_DIR/install_soft.sh"

NGINX_VERSION="${FLATCMS_NGINX_VERSION:-1.24}"
PHP_VERSION="${FLATCMS_PHP_VERSION:-8.5}"
PURE_FTPD_VERSION="${FLATCMS_PURE_FTPD_VERSION:-1.0}"
INSTALL_PURE_FTPD="${FLATCMS_INSTALL_PURE_FTPD:-0}"
REQUIRE_FILEINFO="${FLATCMS_REQUIRE_PHP_FILEINFO:-1}"
PHP_SHORT="${PHP_VERSION/./}"
PHP_DIR="/www/server/php/${PHP_SHORT}"
PHP_BIN="$PHP_DIR/bin/php"
PHP_CONFIG="$PHP_DIR/bin/php-config"
PHPIZE="$PHP_DIR/bin/phpize"
PHP_FPM_SERVICE="php-fpm-${PHP_SHORT}"
PHP_FPM_SOCKET="/tmp/php-cgi-${PHP_SHORT}.sock"

install_soft() {
  local name="$1"
  local version="$2"

  [ -f "$INSTALL_SOFT" ] || fail "aaPanel installer not found: $INSTALL_SOFT"

  log "Installing aaPanel app: $name $version"
  (
    cd "$INSTALL_DIR"
    bash install_soft.sh 4 install "$name" "$version"
  )
}

wait_for_path() {
  local path="$1"
  local label="$2"
  local attempts="${3:-120}"

  for _ in $(seq 1 "$attempts"); do
    if [ -e "$path" ]; then
      log "$label is ready: $path"
      return 0
    fi
    sleep 5
  done

  fail "$label was not ready after waiting for: $path"
}

ensure_temp_swap() {
  local swap_file="${FHS_SWAP_FILE:-/swapfile-flatcms-build}"
  local swap_mb="${FHS_SWAP_MB:-2048}"

  if swapon --show=NAME | grep -qx "$swap_file"; then
    return 0
  fi

  if [ -f "$swap_file" ]; then
    chmod 600 "$swap_file" || true
    swapon "$swap_file" 2>/dev/null || true
    return 0
  fi

  log "Creating temporary ${swap_mb}MB swap file for PHP extension builds."
  if command -v fallocate >/dev/null 2>&1; then
    fallocate -l "${swap_mb}M" "$swap_file" || dd if=/dev/zero of="$swap_file" bs=1M count="$swap_mb"
  else
    dd if=/dev/zero of="$swap_file" bs=1M count="$swap_mb"
  fi
  chmod 600 "$swap_file"
  mkswap "$swap_file"
  swapon "$swap_file"
}

reload_php_fpm() {
  if [ -x "/etc/init.d/$PHP_FPM_SERVICE" ]; then
    /etc/init.d/"$PHP_FPM_SERVICE" reload 2>/dev/null || /etc/init.d/"$PHP_FPM_SERVICE" restart 2>/dev/null || true
  fi
  service "$PHP_FPM_SERVICE" reload 2>/dev/null || service "$PHP_FPM_SERVICE" restart 2>/dev/null || true
  sleep 3
}

php_has_extension() {
  "$PHP_BIN" -m 2>/dev/null | grep -qi "^$1$"
}

ensure_php_fileinfo() {
  if [ "$REQUIRE_FILEINFO" != "1" ]; then
    log "PHP fileinfo requirement disabled by configuration."
    write_report_value "AAPANEL_PHP_FILEINFO" "skipped"
    return 0
  fi

  if php_has_extension fileinfo; then
    log "PHP ${PHP_VERSION} fileinfo extension is already enabled."
    write_report_value "AAPANEL_PHP_FILEINFO" "enabled"
    return 0
  fi

  log "PHP ${PHP_VERSION} fileinfo extension is missing; building it from aaPanel PHP sources."
  ensure_temp_swap
  apt-get update
  apt-get install -y build-essential autoconf pkg-config make gcc

  if [ -d "$PHP_DIR/src/ext/fileinfo" ] && [ -x "$PHPIZE" ] && [ -x "$PHP_CONFIG" ]; then
    (
      cd "$PHP_DIR/src/ext/fileinfo"
      "$PHPIZE"
      ./configure --with-php-config="$PHP_CONFIG"
      make -j1
      make install
    )

    ext_file="$("$PHP_CONFIG" --extension-dir)/fileinfo.so"
    if [ -f "$ext_file" ]; then
      grep -qF "$ext_file" "$PHP_DIR/etc/php.ini" || printf 'extension = %s\n' "$ext_file" >> "$PHP_DIR/etc/php.ini"
      grep -qF "$ext_file" "$PHP_DIR/etc/php-cli.ini" || printf 'extension = %s\n' "$ext_file" >> "$PHP_DIR/etc/php-cli.ini"
      reload_php_fpm
    fi
  fi

  if ! php_has_extension fileinfo; then
    fail "PHP ${PHP_VERSION} fileinfo extension is missing. In aaPanel, use PHP-${PHP_VERSION} > Manage > Install Extensions > fileinfo, then rerun the installer."
  fi

  log "PHP ${PHP_VERSION} fileinfo extension enabled."
  write_report_value "AAPANEL_PHP_FILEINFO" "enabled"
}

ensure_pure_ftpd_requirements() {
  if ! id ftp >/dev/null 2>&1; then
    log "Creating missing ftp system account for Pure-Ftpd."
    useradd -r -s /usr/sbin/nologin -d /var/ftp ftp
  fi

  mkdir -p /var/ftp
  chown ftp:ftp /var/ftp

  if [ ! -f /etc/ssl/private/pure-ftpd.pem ]; then
    log "Creating local Pure-Ftpd TLS certificate."
    mkdir -p /etc/ssl/private
    openssl req -x509 -nodes -newkey rsa:2048 \
      -keyout /etc/ssl/private/pure-ftpd.pem \
      -out /etc/ssl/private/pure-ftpd.pem \
      -days 3650 \
      -subj "/CN=localhost"
    chmod 600 /etc/ssl/private/pure-ftpd.pem
  fi
}

if [ "$INSTALL_STACK" != "1" ]; then
  log "aaPanel stack installation disabled by configuration."
  write_report_value "AAPANEL_STACK_STATUS" "skipped"
  exit 0
fi

if [ ! -f "$INSTALL_SOFT" ]; then
  fail "aaPanel is installed but its internal app installer is missing: $INSTALL_SOFT"
fi

if [ ! -x /www/server/nginx/sbin/nginx ]; then
  install_soft nginx "$NGINX_VERSION"
else
  log "aaPanel Nginx already installed."
fi
wait_for_path /www/server/nginx/sbin/nginx "aaPanel Nginx"

if [ ! -x "$PHP_BIN" ]; then
  install_soft php "$PHP_VERSION"
else
  log "aaPanel PHP ${PHP_VERSION} already installed."
fi
wait_for_path "$PHP_BIN" "aaPanel PHP ${PHP_VERSION}"
wait_for_path "$PHP_FPM_SOCKET" "aaPanel PHP ${PHP_VERSION} FPM socket"
ensure_php_fileinfo
reload_php_fpm
wait_for_path "$PHP_FPM_SOCKET" "aaPanel PHP ${PHP_VERSION} FPM socket after reload" 24

if [ "$INSTALL_PURE_FTPD" = "1" ]; then
  if [ ! -x /www/server/pure-ftpd/bin/pure-pw ]; then
    install_soft pure-ftpd "$PURE_FTPD_VERSION"
  else
    log "aaPanel Pure-Ftpd already installed."
  fi
  wait_for_path /www/server/pure-ftpd/bin/pure-pw "aaPanel Pure-Ftpd"

  ensure_pure_ftpd_requirements
  service pure-ftpd restart 2>/dev/null || service pure-ftpd start 2>/dev/null || true
  write_report_value "AAPANEL_PURE_FTPD_VERSION" "$PURE_FTPD_VERSION"
else
  log "Pure-Ftpd installation disabled by configuration."
  write_report_value "AAPANEL_PURE_FTPD_VERSION" "skipped"
fi

write_report_value "AAPANEL_STACK_STATUS" "installed"
write_report_value "AAPANEL_NGINX_VERSION" "$NGINX_VERSION"
write_report_value "AAPANEL_PHP_VERSION" "$PHP_VERSION"
write_report_value "FLATCMS_PHP_FASTCGI_PASS" "unix:${PHP_FPM_SOCKET}"
