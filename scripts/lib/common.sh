#!/usr/bin/env bash
# Thư viện dùng chung cho các script (được source, không chạy trực tiếp).
# Cung cấp: log(), on_err(), die(), load_env(), send_alert().

LOG_FILE="${LOG_FILE:-/var/tmp/webapp-tools.log}"
APP_ENV="${APP_ENV:-/etc/webapp/app.env}"
APP_DIR="${APP_DIR:-/opt/webapp}"
BACKUP_DIR="${BACKUP_DIR:-/mnt/backup}"
ALERT_TO="${ALERT_TO:-sysadmin@localhost}"

log() {
    local level="$1"; shift
    printf '%s [%s] [%s] %s\n' "$(date '+%F %T')" "${SCRIPT_NAME:-script}" "$level" "$*" | tee -a "$LOG_FILE" >&2
}

on_err() {
    log ERROR "Lỗi (exit=$1) tại dòng $2"
}

die() {
    log ERROR "$*"
    exit 1
}

# Nạp biến từ app.env (DB_HOST, DB_NAME, DB_USER, DB_PASSWORD, ...)
load_env() {
    [[ -r "$APP_ENV" ]] || die "Không đọc được $APP_ENV"
    set -a
    # shellcheck disable=SC1090
    source "$APP_ENV"
    set +a
}

# Gửi cảnh báo qua mail hoặc msmtp (sửa/ thêm Telegram nếu muốn)
send_alert() {
    local subject="$1" body="$2"
    if command -v mail >/dev/null 2>&1; then
        printf '%s\n' "$body" | mail -s "$subject" "$ALERT_TO"
    elif command -v msmtp >/dev/null 2>&1; then
        printf 'To: %s\nSubject: %s\n\n%s\n' "$ALERT_TO" "$subject" "$body" | msmtp "$ALERT_TO"
    else
        log WARN "Không có mail/msmtp - không gửi được cảnh báo: $subject"
        return 1
    fi
    log INFO "Đã gửi cảnh báo: $subject"
}
