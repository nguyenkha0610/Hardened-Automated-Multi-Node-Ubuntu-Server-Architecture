#!/usr/bin/env bash
# deploy.sh - Triển khai app/site, kiểm tra cấu hình, reload an toàn, tự rollback khi lỗi.
# Tác giả: TV2
set -euo pipefail

export SCRIPT_NAME="deploy"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

SRC="$SCRIPT_DIR/../app"
OWNER="webapp:webapp"
SERVICE="webapp"
PREV_DIR=""

usage() {
    cat <<USAGE
Dùng: $0 [-s nguồn] [-t đích] [-o owner:group] [-S service] [-h]
  -s  Thư mục mã nguồn   (mặc định: $SRC)
  -t  Thư mục triển khai (mặc định: $APP_DIR)
  -o  Chủ sở hữu         (mặc định: $OWNER)
  -S  Tên service systemd(mặc định: $SERVICE)
  -h, --help  Hiển thị trợ giúp
USAGE
}

[[ "${1:-}" == "--help" ]] && { usage; exit 0; }
while getopts ":s:t:o:S:h" opt; do
    case "$opt" in
        s) SRC="$OPTARG" ;;
        t) APP_DIR="$OPTARG" ;;
        o) OWNER="$OPTARG" ;;
        S) SERVICE="$OPTARG" ;;
        h) usage; exit 0 ;;
        *) usage; exit 2 ;;
    esac
done

rollback() {
    if [[ -n "$PREV_DIR" && -d "$PREV_DIR" ]]; then
        log WARN "ROLLBACK về bản ổn định trước đó: $PREV_DIR"
        rsync -a --delete "$PREV_DIR/" "$APP_DIR/"
        chown -R "$OWNER" "$APP_DIR"
        nginx -t && systemctl reload nginx || true
        systemctl restart "$SERVICE" || true
        log WARN "Rollback hoàn tất"
    else
        log ERROR "Không có bản trước để rollback"
    fi
}

DEPLOY_OK=0
trap 'on_err "$?" "$LINENO"' ERR
trap '[[ $DEPLOY_OK -eq 1 ]] || rollback' EXIT

[[ $EUID -eq 0 ]] || die "Cần chạy bằng sudo"
[[ -d "$SRC" ]] || die "Không thấy thư mục nguồn: $SRC"

# 1. Lưu bản hiện tại để rollback
PREV_DIR="$(mktemp -d /var/tmp/webapp-prev.XXXXXX)"
[[ -d "$APP_DIR" ]] && rsync -a "$APP_DIR/" "$PREV_DIR/"
log INFO "Đã lưu bản hiện tại vào $PREV_DIR"

# 2. Copy mã nguồn + phân quyền
mkdir -p "$APP_DIR"
rsync -a --delete --exclude 'venv' --exclude '.env*' "$SRC/" "$APP_DIR/"
chown -R "$OWNER" "$APP_DIR"
find "$APP_DIR" -type d -exec chmod 750 {} +
find "$APP_DIR" -type f -exec chmod 640 {} +
log INFO "Đã copy mã nguồn và phân quyền"

# 3. Test cấu hình -> reload -> xác nhận
nginx -t || die "nginx -t thất bại"
systemctl restart "$SERVICE"
systemctl reload nginx
sleep 2
systemctl is-active --quiet "$SERVICE" || die "Service $SERVICE không active sau deploy"
curl -fsS --max-time 5 http://127.0.0.1:8000/health >/dev/null || die "Health endpoint lỗi sau deploy"

DEPLOY_OK=1
rm -rf "$PREV_DIR"
log INFO "Deploy THÀNH CÔNG"
