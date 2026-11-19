#!/usr/bin/env bash
# install-configs.sh - TV1 dùng khi GHÉP: copy configs/vm1 vào đúng thư mục hệ thống trên VM1.
set -euo pipefail

export SCRIPT_NAME="install-configs"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
C="$SCRIPT_DIR/../configs/vm1"

case "${1:-}" in -h|--help) echo "Dùng: sudo $0  (copy configs/vm1 -> /etc/...)"; exit 0 ;; esac
trap 'on_err "$?" "$LINENO"' ERR
[[ $EUID -eq 0 ]] || die "Cần sudo"

install -m 644 "$C/nginx/webapp.conf" /etc/nginx/sites-available/webapp.conf
install -m 644 "$C/nginx/status.conf" /etc/nginx/sites-available/status.conf
install -d /etc/nginx/snippets
install -m 644 "$C/nginx/snippets/self-signed.conf" /etc/nginx/snippets/self-signed.conf
ln -sf /etc/nginx/sites-available/webapp.conf /etc/nginx/sites-enabled/webapp.conf
ln -sf /etc/nginx/sites-available/status.conf /etc/nginx/sites-enabled/status.conf
install -m 644 "$C"/systemd/*.service "$C"/systemd/*.timer /etc/systemd/system/
install -m 644 "$C/security/jail.local" /etc/fail2ban/jail.local
install -m 640 "$C/security/audit.rules" /etc/audit/rules.d/99-webapp.rules
install -m 644 "$C/system/99-hardening.conf" /etc/ssh/sshd_config.d/99-hardening.conf

install -d -m 750 -o root -g root /etc/webapp
if [[ ! -f /etc/webapp/app.env ]]; then
    install -m 600 "$SCRIPT_DIR/../app/.env.example" /etc/webapp/app.env
    log WARN "Đã tạo /etc/webapp/app.env từ mẫu - HÃY SỬA MẬT KHẨU"
fi
chmod +x "$SCRIPT_DIR"/*.sh
systemctl daemon-reload
nginx -t
log INFO "Đã áp cấu hình. Kiểm tra sshd: sshd -t, rồi reload từng dịch vụ."
