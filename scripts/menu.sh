#!/usr/bin/env bash
# menu.sh - Menu CLI điều phối deploy / backup / restore / health-check / log-rotate.
# Tác giả: TV4
set -euo pipefail

export SCRIPT_NAME="menu"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() {
    cat <<USAGE
Dùng: $0 [-h]
Menu tương tác điều phối: deploy, backup, restore, health-check, log-rotate.
USAGE
}
case "${1:-}" in -h|--help) usage; exit 0 ;; esac

trap 'on_err "$?" "$LINENO"' ERR
trap 'log INFO "Thoát menu"' EXIT

# Chạy 1 công cụ; lỗi của công cụ không làm sập menu
run_tool() {
    local tool="$1"; shift
    log INFO "Chạy $tool $*"
    if "$SCRIPT_DIR/$tool" "$@"; then
        log INFO "$tool xong"
    else
        log WARN "$tool kết thúc với lỗi"
    fi
}

while true; do
    cat <<'MENU'

====== QUẢN TRỊ HỆ THỐNG WEBAPP ======
 1) Deploy (có rollback)
 2) Backup
 3) Restore
 4) Health-check
 5) Xoay vòng log
 0) Thoát
MENU
    read -r -p "Chọn [0-5]: " choice
    case "$choice" in
        1) run_tool deploy.sh ;;
        2) run_tool backup.sh ;;
        3) run_tool restore.sh ;;
        4) run_tool health-check.sh ;;
        5)
            read -r -p "Đường dẫn file log: " lf
            read -r -p "Số thế hệ giữ lại [5]: " n
            run_tool log-rotate.sh -f "$lf" -n "${n:-5}"
            ;;
        0) exit 0 ;;
        *) echo "Lựa chọn không hợp lệ: '$choice'. Vui lòng nhập 0-5." ;;
    esac
done
