#!/usr/bin/env bash
# restore.sh - Khôi phục CSDL + file web từ bản backup do backup.sh tạo ra.
# Tác giả: TV4
set -euo pipefail

export SCRIPT_NAME="restore"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

FILE=""
ASSUME_YES=0
WORKDIR=""

usage() {
    cat <<USAGE
Dùng: $0 [-f file.tar.gz] [-y] [-h]
  -f  File backup cần khôi phục (mặc định: bản mới nhất trong $BACKUP_DIR)
  -y  Không hỏi xác nhận
  -h, --help  Trợ giúp
USAGE
}

[[ "${1:-}" == "--help" ]] && { usage; exit 0; }
while getopts ":f:yh" opt; do
    case "$opt" in
        f) FILE="$OPTARG" ;;
        y) ASSUME_YES=1 ;;
        h) usage; exit 0 ;;
        *) usage; exit 2 ;;
    esac
done

cleanup() { [[ -n "$WORKDIR" && -d "$WORKDIR" ]] && rm -rf "$WORKDIR"; return 0; }
trap 'on_err "$?" "$LINENO"' ERR
trap cleanup EXIT

load_env
if [[ -z "$FILE" ]]; then
    FILE="$(find "$BACKUP_DIR" -maxdepth 1 -name 'webapp_backup_*.tar.gz' | sort | tail -n1)"
fi
[[ -n "$FILE" && -f "$FILE" ]] || die "Không tìm thấy file backup"

if [[ $ASSUME_YES -ne 1 ]]; then
    read -r -p "Khôi phục từ $FILE ? Dữ liệu hiện tại sẽ bị ghi đè [y/N]: " ans
    [[ "$ans" =~ ^[yY]$ ]] || { log INFO "Đã hủy"; exit 0; }
fi

WORKDIR="$(mktemp -d)"
tar -xzf "$FILE" -C "$WORKDIR"
[[ -f "$WORKDIR/db.sql" ]] || die "Backup không có db.sql"

log INFO "Khôi phục CSDL $DB_NAME"
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "${DB_PORT:-5432}" -U "$DB_USER" \
    -d "$DB_NAME" -v ON_ERROR_STOP=1 -q -f "$WORKDIR/db.sql"

if [[ -d "$WORKDIR/${APP_DIR#/}" ]]; then
    log INFO "Khôi phục file web/app vào $APP_DIR"
    rsync -a --delete "$WORKDIR/${APP_DIR#/}/" "$APP_DIR/"
    systemctl restart webapp || log WARN "Không restart được webapp"
fi
log INFO "Restore HOÀN TẤT từ $(basename "$FILE")"
