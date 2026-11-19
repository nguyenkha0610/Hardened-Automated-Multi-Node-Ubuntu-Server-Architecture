# Tái tạo hệ thống (điền chi tiết khi hoàn thành)
1. Cài Ubuntu 22.04 Server ×2, hostname `vm1-service`, `vm2-backup`, user `sysadmin`.
2. Gắn đĩa phụ, `mkfs.ext4`, thêm `fstab`, `mount -a`.
3. SSH key trên VM1 → `ssh-copy-id -p 2222 sysadmin@vm2-backup`.
4. Cài gói: `nginx postgresql python3-venv fail2ban auditd ufw lynis msmtp mailutils rsync`.
5. `git clone` → `sudo scripts/install-configs.sh` → sửa `/etc/webapp/app.env`.
6. `sudo -u postgres psql -f configs/vm1/db/setup.sql`, rồi nạp `app/schema.sql`.
7. `sudo bash configs/vm1/nginx/gen-cert.sh`, `sudo bash configs/vm1/system/ufw-rules.sh`.
8. `sudo scripts/deploy.sh`, `systemctl enable --now webapp backup.timer`.
