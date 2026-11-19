# Checklist theo đề (đánh dấu khi có bằng chứng)

## Hệ thống & lưu trữ
- [ ] Ubuntu 22.04 Server, hostname có ý nghĩa
- [ ] User non-root có sudo
- [ ] Phân vùng backup mount qua /etc/fstab, sống sót sau reboot
- [ ] ≥ 2 VM, có sơ đồ trong báo cáo
## Bảo mật
- [ ] UFW mặc định chặn vào; giải thích từng cổng mở
- [ ] SSH: tắt root, khóa, đổi cổng/AllowUsers
- [ ] fail2ban ban được trực tiếp
- [ ] auditd theo dõi /etc/passwd, /etc/shadow
- [ ] Lynis: điểm trước/sau, khắc phục ≥ 3 mục
- [ ] DB chỉ nghe 127.0.0.1 (ảnh `ss -ltnp`)
- [ ] app.env quyền 600 (ảnh `ls -l`)
## Web & TLS
- [ ] Nginx reverse proxy + header đúng
- [ ] ≥ 2 virtual host (curl -H "Host: ...")
- [ ] TLS tự ký, 80→443, mở 443
## App & systemd
- [ ] GET + POST hoạt động đầu-cuối
- [ ] systemctl status: active + enabled
- [ ] kill app → tự restart (journalctl)
## Tự động hóa & sao lưu
- [ ] deploy: lỗi → rollback
- [ ] backup: nén, timestamp, retention, rsync sang VM2
- [ ] lịch cron/systemd timer
- [ ] restore trực tiếp, dữ liệu nguyên vẹn
- [ ] health-check + cảnh báo mail/msmtp thật
- [ ] menu xử lý nhập sai
- [ ] set -euo pipefail + trap ERR/EXIT; --help; shellcheck sạch
## Nộp bài
- [ ] Báo cáo PDF 6–12 trang
- [ ] README đủ: hướng, sơ đồ, phân công, tái tạo
- [ ] Snapshot VM1+VM2
- [ ] File MSSV1_MSSV2_MSSV3_MSSV4.tar.gz
