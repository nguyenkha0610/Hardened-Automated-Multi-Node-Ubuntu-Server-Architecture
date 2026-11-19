# Kịch bản demo 12–15 phút
| Phút | Nội dung | Lệnh gợi ý | Phụ trách |
|------|----------|------------|-----------|
| 0–2 | Hệ thống chạy, tường lửa, dịch vụ | `sudo ufw status verbose`, `systemctl status nginx webapp postgresql` | TV1 |
| 2–5 | HTTPS, 2 vhost, 80→443, DB chỉ localhost | `curl -kI http://lab.local`, `curl -k -H "Host: status.lab.local" https://<IP>`, `ss -ltnp` | TV2/TV3 |
| 5–7 | App tự hồi phục | `sudo pkill -f gunicorn; journalctl -u webapp -n 20` | TV3 |
| 7–9 | fail2ban ban, auditd | `sudo fail2ban-client status sshd`, `sudo ausearch -k shadow_access -i` | TV1 |
| 9–11 | Deploy lỗi → rollback | cố tình sửa nginx conf sai → `sudo scripts/deploy.sh` | TV2 |
| 11–13 | Backup → xóa dữ liệu → restore | `scripts/backup.sh`, `DROP TABLE notes;`, `scripts/restore.sh -y` | TV4 |
| 13–15 | Health-check cảnh báo + shellcheck | `sudo systemctl stop nginx; scripts/health-check.sh`, `make lint` | TV4 |

Trước khi demo: **chụp snapshot VM1 + VM2**.
