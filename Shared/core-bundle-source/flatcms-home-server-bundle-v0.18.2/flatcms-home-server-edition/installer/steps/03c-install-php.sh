#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

INSTALL_STACK="${FLATCMS_INSTALL_AAPANEL_STACK:-1}"
INSTALL_DIR="/www/server/panel/install"
INSTALL_SOFT="$INSTALL_DIR/install_soft.sh"
PHP_VERSION="${FLATCMS_PHP_VERSION:-8.5}"
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
  local timeout_seconds="${FHS_AAPANEL_APP_INSTALL_TIMEOUT:-3600}"
  local install_status=0

  [ -f "$INSTALL_SOFT" ] || fail "aaPanel installer not found: $INSTALL_SOFT"
  chmod +x "$INSTALL_SOFT" 2>/dev/null || true

  log "Installing aaPanel app: $name $version"
  log "aaPanel app installer timeout: ${timeout_seconds}s"

  set +e
  set +o pipefail
  (
    cd "$INSTALL_DIR"
    yes y | timeout "$timeout_seconds" bash install_soft.sh 4 install "$name" "$version"
  )
  install_status=$?
  set -o pipefail
  set -e

  if [ "$install_status" -eq 124 ]; then
    fail "aaPanel app installer timed out while installing: $name $version"
  fi

  if [ "$install_status" -ne 0 ]; then
    log "aaPanel app installer returned exit code $install_status for $name $version; continuing to verify filesystem result."
  else
    log "aaPanel app installer command completed for $name $version."
  fi
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

if [ "$INSTALL_STACK" != "1" ]; then
  log "aaPanel stack installation disabled by configuration."
  write_report_value "AAPANEL_PHP_STATUS" "skipped"
  exit 0
fi

if [ ! -f "$INSTALL_SOFT" ]; then
  fail "aaPanel is installed but its internal app installer is missing: $INSTALL_SOFT"
fi

log "aaPanel internal app installer is available: $INSTALL_SOFT"
log "Ensuring PHP build dependencies are installed."
apt-get update
apt-get install -y libc-ares-dev

if [ ! -x "$PHP_BIN" ]; then
  if [ -d "$PHP_DIR" ]; then
    log "Removing incomplete PHP ${PHP_VERSION} directory before reinstall: $PHP_DIR"
    rm -rf "$PHP_DIR"
  fi
  install_soft php "$PHP_VERSION"
else
  log "aaPanel PHP ${PHP_VERSION} already installed."
fi

wait_for_path "$PHP_BIN" "aaPanel PHP ${PHP_VERSION}"
wait_for_path "$PHP_FPM_SOCKET" "aaPanel PHP ${PHP_VERSION} FPM socket"
ensure_php_fileinfo
reload_php_fpm
wait_for_path "$PHP_FPM_SOCKET" "aaPanel PHP ${PHP_VERSION} FPM socket after reload" 24

PHP_RUNTIME_VERSION="$($PHP_BIN -v | head -1)"

write_report_value "AAPANEL_STACK_STATUS" "installed"
write_report_value "AAPANEL_PHP_STATUS" "installed"
write_report_value "AAPANEL_PHP_VERSION" "$PHP_VERSION"
write_report_value "FLATCMS_PHP_FASTCGI_PASS" "unix:${PHP_FPM_SOCKET}"
write_report_value "CHECK_PHP${PHP_SHORT}" "ok"
write_report_value "CHECK_PHP${PHP_SHORT}_VERSION" "$PHP_RUNTIME_VERSION"
write_report_value "CHECK_PHP${PHP_SHORT}_SOCKET" "$PHP_FPM_SOCKET"
write_report_value "CHECK_PHP85" "ok"
write_report_value "CHECK_PHP85_VERSION" "$PHP_RUNTIME_VERSION"
write_report_value "CHECK_PHP85_SOCKET" "$PHP_FPM_SOCKET"
if php_has_extension fileinfo; then
  write_report_value "CHECK_PHP${PHP_SHORT}_FILEINFO" "ok"
  write_report_value "CHECK_PHP85_FILEINFO" "ok"
else
  write_report_value "CHECK_PHP${PHP_SHORT}_FILEINFO" "missing"
  write_report_value "CHECK_PHP85_FILEINFO" "missing"
fi
