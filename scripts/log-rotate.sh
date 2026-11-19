#!/usr/bin/env bash
# log-rotate.sh - Xoay vòng + nén 1 file log, giữ N thế hệ, xóa bản cũ hơn.
# Tác giả: TV2
set -euo pipefail

export SCRIPT_NAME="log-rotate"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

LOGFILE=""
KEEP=5

usage() {
    cat <<USAGE
Dùng: $0 -f /đường/dẫn/file.log [-n số_thế_hệ] [-h]
  -f  File log cần xoay (bắt buộc)
  -n  Số thế hệ giữ lại (mặc định: $KEEP)
  -h, --help  Trợ giúp
USAGE
}

[[ "${1:-}" == "--help" ]] && { usage; exit 0; }
while getopts ":f:n:h" opt; do
    case "$opt" in
        f) LOGFILE="$OPTARG" ;;
        n) KEEP="$OPTARG" ;;
        h) usage; exit 0 ;;
        *) usage; exit 2 ;;
    esac
done

trap 'on_err "$?" "$LINENO"' ERR
trap 'log INFO "Kết thúc log-rotate"' EXIT

[[ -n "$LOGFILE" ]] || { usage; die "Thiếu -f"; }
[[ -f "$LOGFILE" ]] || die "Không thấy file: $LOGFILE"
[[ "$KEEP" =~ ^[0-9]+$ && "$KEEP" -ge 1 ]] || die "-n phải là số nguyên >= 1"

ROTATED="${LOGFILE}.$(date '+%Y%m%d_%H%M%S').gz"
gzip -c "$LOGFILE" > "$ROTATED"
: > "$LOGFILE"   # copytruncate: giữ nguyên file đang được ghi
log INFO "Đã xoay: $ROTATED"

# Giữ N thế hệ mới nhất, xóa phần còn lại
mapfile -t old < <(find "$(dirname "$LOGFILE")" -maxdepth 1 -name "$(basename "$LOGFILE").*.gz" | sort -r | tail -n +"$((KEEP + 1))")
for f in "${old[@]}"; do
    rm -f -- "$f"
    log INFO "Đã xóa thế hệ cũ: $f"
done
