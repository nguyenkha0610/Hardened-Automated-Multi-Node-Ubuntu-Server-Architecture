# Đồ án cuối kỳ – Hệ điều hành Linux & Ứng dụng

> Nhóm: `<TÊN NHÓM>` – Trình ảo hóa: `<VirtualBox/VMware>` – OS: `Ubuntu 22.04 LTS Server`

## 1. Hướng đồ án đã chọn
Hệ thống hợp nhất: **Nginx (reverse proxy, 2 vhost, HTTPS tự ký) → Flask/gunicorn (systemd) → PostgreSQL (localhost)**,
vận hành bằng bộ công cụ Bash (menu, deploy, backup, restore, health-check, log-rotate), sao lưu rsync sang VM2.

## 2. Sơ đồ VM
```
 Client (curl/browser)
        │ 80/443
        ▼
┌─────────────────────────── VM1: vm1-service (<IP1>) ───────────────────────────┐
│ UFW ▸ Nginx (vhost app + vhost status) ▸ gunicorn/Flask 127.0.0.1:8000 (systemd)│
│                                         ▸ PostgreSQL 127.0.0.1:5432             │
│ fail2ban · auditd · scripts/ (menu, deploy, backup, restore, health, logrotate) │
└───────────────────────────────┬─────────────────────────────────────────────────┘
                                │ rsync over SSH (key, không mật khẩu)
                                ▼
                ┌──────── VM2: vm2-backup (<IP2>) ────────┐
                │ /mnt/backup (mount qua fstab) · bastion │
                └─────────────────────────────────────────┘
```
Mạng: `<Host-Only / Internal>` – dải `<192.168.56.0/24>`.

## 3. Bảng phân công
| TV | Họ tên | MSSV | Vai trò | Thư mục phụ trách |
|----|--------|------|---------|-------------------|
| 1 (Leader) | | | Hạ tầng, mạng, bảo mật lõi | `configs/vm1/system`, `configs/vm1/security`, `configs/vm2` |
| 2 | | | Nginx, TLS, deploy, log-rotate | `configs/vm1/nginx`, `scripts/deploy.sh`, `scripts/log-rotate.sh` |
| 3 | | | Ứng dụng, CSDL, systemd | `app/`, `configs/vm1/db`, `configs/vm1/systemd/webapp.service` |
| 4 | | | Backup, restore, health-check, menu | `scripts/backup.sh`, `restore.sh`, `health-check.sh`, `menu.sh` |

> Đề gốc yêu cầu nhóm 5 SV: nếu nhóm đủ 5 người, thêm dòng và chia lại (gợi ý: tách CSDL & sao lưu thành vai riêng).

## 4. Hằng số dùng chung (khóa cứng trên mọi VM)
| Mục | Giá trị |
|-----|---------|
| User quản trị | `sysadmin` (sudo, non-root) |
| Mã nguồn chạy | `/opt/webapp` |
| Bí mật | `/etc/webapp/app.env` (`chmod 600`, owner `root:webapp`) |
| App | `127.0.0.1:8000` |
| CSDL | PostgreSQL `127.0.0.1:5432`, db `webappdb`, role `webapp_user` |
| Backup | `/mnt/backup` (VM1 local & VM2, mount qua fstab) |
| Cổng SSH | `2222` |
| Log công cụ | `/var/log/webapp-tools.log` |

## 5. Tái tạo hệ thống (tóm tắt – xem `docs/REBUILD.md`)
```bash
# Trên VM1
git clone <repo-url> && cd linux-final-project
sudo ./scripts/install-configs.sh        # copy configs/ -> /etc/..., tạo app.env từ mẫu
sudo ./scripts/menu.sh
```

## 6. Quy trình Git
Xem [`CONTRIBUTING.md`](CONTRIBUTING.md). Kiểm tra checklist: [`docs/CHECKLIST.md`](docs/CHECKLIST.md). Kịch bản demo: [`docs/DEMO_SCRIPT.md`](docs/DEMO_SCRIPT.md).
