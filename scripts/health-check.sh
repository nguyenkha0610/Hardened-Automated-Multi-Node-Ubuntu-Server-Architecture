#!/usr/bin/env bash
# health-check.sh - Kiểm tra CPU/RAM/đĩa/cổng/dịch vụ so với ngưỡng, ghi log + cảnh báo.
# Tác giả: TV4
set -euo pipefail

export SCRIPT_NAME="health-check"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

CPU_MAX=85
RAM_MAX=85
DISK_MAX=85
SERVICES=(nginx webapp postgresql)
PORTS=(80 443 8000 5432)
PROBLEMS=()

usage() {
    cat <<USAGE
Dùng: $0 [-c cpu%] [-m ram%] [-d disk%] [-s "svc1 svc2"] [-p "port1 port2"] [-h]
  -c  Ngưỡng CPU  (mặc định: $CPU_MAX)
  -m  Ngưỡng RAM  (mặc định: $RAM_MAX)
  -d  Ngưỡng đĩa / (mặc định: $DISK_MAX)
  -s  Danh sách service (mặc định: ${SERVICES[*]})
  -p  Danh sách cổng    (mặc định: ${PORTS[*]})
  -h, --help  Trợ giúp
USAGE
}

[[ "${1:-}" == "--help" ]] && { usage; exit 0; }
while getopts ":c:m:d:s:p:h" opt; do
    case "$opt" in
        c) CPU_MAX="$OPTARG" ;;
        m) RAM_MAX="$OPTARG" ;;
        d) DISK_MAX="$OPTARG" ;;
        s) read -r -a SERVICES <<< "$OPTARG" ;;
        p) read -r -a PORTS <<< "$OPTARG" ;;
        h) usage; exit 0 ;;
        *) usage; exit 2 ;;
    esac
done

trap 'on_err "$?" "$LINENO"' ERR
trap 'log INFO "Kết thúc health-check"' EXIT

add_problem() { PROBLEMS+=("$1"); log WARN "$1"; }

# CPU: 100 - %idle (lấy mẫu 1 giây)
cpu_idle="$(top -bn2 -d1 | awk '/Cpu\(s\)/ {idle=$8} END {print idle}')"
cpu_used="$(awk -v i="${cpu_idle//,/.}" 'BEGIN {printf "%d", 100 - i}')"
[[ "$cpu_used" -le "$CPU_MAX" ]] || add_problem "CPU ${cpu_used}% > ${CPU_MAX}%"

ram_used="$(free | awk '/^Mem:/ {printf "%d", $3 * 100 / $2}')"
[[ "$ram_used" -le "$RAM_MAX" ]] || add_problem "RAM ${ram_used}% > ${RAM_MAX}%"

disk_used="$(df -P / | awk 'NR==2 {gsub("%",""); print $5}')"
[[ "$disk_used" -le "$DISK_MAX" ]] || add_problem "Disk / ${disk_used}% > ${DISK_MAX}%"

for svc in "${SERVICES[@]}"; do
    systemctl is-active --quiet "$svc" || add_problem "Service $svc KHÔNG chạy"
done

for port in "${PORTS[@]}"; do
    ss -ltn | awk '{print $4}' | grep -qE "[:.]${port}\$" || add_problem "Cổng $port KHÔNG lắng nghe"
done

log INFO "CPU=${cpu_used}% RAM=${ram_used}% DISK=${disk_used}%"
if [[ ${#PROBLEMS[@]} -gt 0 ]]; then
    send_alert "[ALERT] $(hostname): ${#PROBLEMS[@]} vấn đề" "$(printf '%s\n' "${PROBLEMS[@]}")" || true
    exit 1
fi
log INFO "Hệ thống bình thường"
