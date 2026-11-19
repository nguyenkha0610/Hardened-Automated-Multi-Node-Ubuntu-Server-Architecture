#!/usr/bin/env bash
# backup.sh - Dump CSDL + nén web/app, gắn nhãn thời gian, retention, rsync sang VM2.
# Tác giả: TV4
set -euo pipefail

export SCRIPT_NAME="backup"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

RETENTION_DAYS=7
REMOTE="sysadmin@vm2-backup:/mnt/backup/"
SSH_PORT=2222
MIN_FREE_MB=500
WORKDIR=""

usage() {
    cat <<USAGE
Dùng: $0 [-r số_ngày] [-d thư_mục_backup] [-R user@host:/path/] [-p ssh_port] [-h]
  -r  Số ngày lưu giữ        (mặc định: $RETENTION_DAYS)
  -d  Thư mục backup cục bộ  (mặc định: $BACKUP_DIR)
  -R  Đích rsync trên VM2    (mặc định: $REMOTE)
  -p  Cổng SSH của VM2       (mặc định: $SSH_PORT)
  -h, --help  Trợ giúp
USAGE
}

[[ "${1:-}" == "--help" ]] && { usage; exit 0; }
while getopts ":r:d:R:p:h" opt; do
    case "$opt" in
        r) RETENTION_DAYS="$OPTARG" ;;
        d) BACKUP_DIR="$OPTARG" ;;
        R) REMOTE="$OPTARG" ;;
        p) SSH_PORT="$OPTARG" ;;
        h) usage; exit 0 ;;
        *) usage; exit 2 ;;
    esac
done

cleanup() { [[ -n "$WORKDIR" && -d "$WORKDIR" ]] && rm -rf "$WORKDIR"; return 0; }
fail() {
    on_err "$1" "$2"
    send_alert "[BACKUP FAILED] $(hostname)" "Backup lỗi tại dòng $2 (exit $1). Xem $LOG_FILE" || true
}
trap 'fail "$?" "$LINENO"' ERR
trap cleanup EXIT

load_env
[[ -d "$BACKUP_DIR" ]] || die "Thư mục backup không tồn tại: $BACKUP_DIR"

# Kiểm tra dung lượng đĩa trước khi sao lưu (tình huống đĩa đầy lúc 2h sáng)
free_mb="$(df -Pm "$BACKUP_DIR" | awk 'NR==2 {print $4}')"
[[ "$free_mb" -ge "$MIN_FREE_MB" ]] || die "Đĩa gần đầy: còn ${free_mb}MB < ${MIN_FREE_MB}MB"

TS="$(date '+%Y%m%d_%H%M%S')"
WORKDIR="$(mktemp -d)"
ARCHIVE="$BACKUP_DIR/webapp_backup_${TS}.tar.gz"

log INFO "Dump CSDL $DB_NAME"
PGPASSWORD="$DB_PASSWORD" pg_dump -h "$DB_HOST" -p "${DB_PORT:-5432}" -U "$DB_USER" \
    --clean --if-exists "$DB_NAME" > "$WORKDIR/db.sql"

log INFO "Nén CSDL + $APP_DIR -> $ARCHIVE"
tar -czf "$ARCHIVE" -C "$WORKDIR" db.sql -C / "${APP_DIR#/}"
log INFO "Đã tạo $(basename "$ARCHIVE") ($(du -h "$ARCHIVE" | cut -f1))"

log INFO "Retention: xóa bản cũ hơn $RETENTION_DAYS ngày"
find "$BACKUP_DIR" -maxdepth 1 -name 'webapp_backup_*.tar.gz' -mtime "+$RETENTION_DAYS" -print -delete | while read -r f; do
    log INFO "Đã xóa bản cũ: $f"
done

log INFO "rsync -> $REMOTE"
rsync -az --delete -e "ssh -p $SSH_PORT" "$BACKUP_DIR/" "$REMOTE"
log INFO "Backup HOÀN TẤT"
