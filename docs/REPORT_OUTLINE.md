# Dàn ý báo cáo (6–12 trang)
1. Tổng quan: hướng chọn, sơ đồ VM, chế độ mạng, bảng phân công
2. Các bước xây dựng (quyết định then chốt, tham chiếu `configs/`)
3. Bảo mật: lý do từng cổng; SSH & đánh đổi; fail2ban; auditd; Lynis trước/sau + 3 mục khắc phục
4. TLS: **vì sao tự ký, không dùng Let's Encrypt** (VM Host-Only/Internal không có tên miền công khai, ACME không truy cập được cổng 80/443) – nhận điểm thưởng
5. Sao lưu & khôi phục: nội dung, lịch, retention, quy trình restore + bằng chứng
6. Tự động hóa: mỗi script (mục đích, tham số, xử lý lỗi, cảnh báo) + kết quả shellcheck
Phụ lục: ảnh chụp đặt trong `docs/evidence/`
