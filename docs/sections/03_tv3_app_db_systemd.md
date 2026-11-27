# 3. Ứng dụng Web, Cơ sở dữ liệu PostgreSQL và Dịch vụ Systemd

**Phụ trách:** Thành viên 3 — Võ Quốc Trung (MSSV: `24120478`)  
**Tệp cấu hình và mã nguồn tham chiếu:** `app/app.py`, `app/requirements.txt`, `app/schema.sql`, `app/.env.example`, `configs/vm1/db/setup.sql`, `configs/vm1/db/postgresql-bind.conf`, `configs/vm1/db/pg_hba.conf`, `configs/vm1/systemd/webapp.service`.

---

## 3.1. Kiến trúc Ứng dụng Web tại `/opt/webapp` và Thiết kế Cơ sở dữ liệu

Trong mô hình tổng thể `Client -> Nginx (HTTPS) -> Ứng dụng WSGI (127.0.0.1:8000) -> PostgreSQL (127.0.0.1:5432)`, tầng ứng dụng được triển khai bằng **Python 3** với **Flask 3.0.3**, chạy qua máy chủ WSGI **Gunicorn 22.0.0** (2 worker tiến trình) trong môi trường ảo cô lập tại `/opt/webapp/venv` và giao tiếp PostgreSQL thông qua thư viện `psycopg2-binary`.

### Cấu trúc thư mục triển khai trên VM1
```text
/opt/webapp/
├── app.py              # Mã nguồn ứng dụng Flask (quyền 640, owner webapp:webapp)
├── requirements.txt    # Khai báo phiên bản Flask, gunicorn, psycopg2-binary
├── schema.sql          # Lược đồ tạo bảng notes và gán quyền sở hữu cho webapp_user
├── .env.example        # Tệp mẫu biến môi trường (không chứa mật khẩu thật)
└── venv/               # Python virtualenv chứa /opt/webapp/venv/bin/gunicorn (+x)
```

Thư mục `/opt/webapp` có quyền `750` (`webapp:webapp`), các tệp mã nguồn đặt quyền `640` để các user không thuộc nhóm `webapp` không thể đọc/sửa, trong khi thư mục `venv/bin/` vẫn giữ quyền thực thi `+x` cho `systemd` khởi chạy Gunicorn.

### Các API endpoint và quyết định thiết kế trong `app/app.py`

| Endpoint | Phương thức | Mã phản hồi | Chức năng |
| :--- | :---: | :---: | :--- |
| `/` | `GET` | `200` | Trả về giao diện HTML tối giản hiển thị và tạo ghi chú trực tiếp qua API. |
| `/health` | `GET` | `200` / `503` | Thực thi `SELECT 1` kiểm tra kết nối PostgreSQL; phục vụ `deploy.sh` và giám sát. |
| `/api/notes` | `GET` | `200` / `503` | Truy vấn tối đa 50 bản ghi mới nhất từ bảng `notes` theo thứ tự `id DESC`. |
| `/api/notes` | `POST` | `201` / `400` / `503` | Kiểm tra hợp lệ nội dung (`1..500` ký tự), ghi bản ghi mới và trả về JSON kèm `id`. |

Một số điểm kỹ thuật chính được áp dụng trong `app/app.py`:
- **Tương thích Reverse Proxy (`ProxyFix`):** Bọc `app.wsgi_app` bằng `werkzeug.middleware.proxy_fix.ProxyFix(..., x_for=1, x_proto=1, x_host=1)` để Flask nhận đúng giao thức HTTPS, tên miền và địa chỉ IP thực từ các header `X-Forwarded-For`, `X-Forwarded-Proto`, `Host` do Nginx chuyển tiếp.
- **Quản lý vòng đời kết nối (`db_cursor`):** Sử dụng `@contextmanager` mở kết nối với `connect_timeout=5`, tự động `commit()` khi truy vấn thành công, `rollback()` khi phát sinh ngoại lệ và luôn gọi `conn.close()` trong khối `finally` nhằm tránh rò rỉ kết nối PostgreSQL. Khi CSDL tạm ngưng, endpoint `/health` và `/api/notes` bắt `psycopg2.Error` để trả HTTP `503` thay vì lỗi 500 không kiểm soát.
- **Vận hành độc lập trên mạng lab cô lập:** Giao diện tại `/` sử dụng HTML/CSS/JS thuần, không phụ thuộc CDN ngoài và render nội dung qua `textContent` để phòng tránh XSS.

### Thiết kế bảng dữ liệu (`app/schema.sql`)
Ứng dụng sử dụng bảng `notes` trong database `webappdb`:

| Cột | Kiểu dữ liệu | Ràng buộc | Ý nghĩa |
| :--- | :--- | :--- | :--- |
| `id` | `SERIAL` | `PRIMARY KEY` | Khóa chính tự tăng qua sequence `notes_id_seq`. |
| `content` | `TEXT` | `NOT NULL`, `CHECK (char_length(content) <= 500)` | Nội dung ghi chú, giới hạn độ dài ngay tại tầng CSDL. |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT now()` | Thời điểm tạo bản ghi kèm múi giờ hệ thống. |

> **[CHÈN ẢNH BẰNG CHỨNG 1 — Chụp trên VM1 Ubuntu 22.04]**  
> ![Kiểm thử API GET/POST đầu-cuối qua Nginx và PostgreSQL](../images/tv3_01_app_api_db.png)  
> *Hình 3.1: Kết quả gọi `POST /api/notes`, `GET /api/notes` qua Nginx HTTPS (hoặc `127.0.0.1:8000`) và đối chiếu dữ liệu đã lưu trong bảng `notes` bằng `psql`.*  
> *(Lệnh gợi ý khi chụp trên VM1: `curl -sk -X POST https://lab.local/api/notes -H 'Content-Type: application/json' -d '{"content":"demo tv3"}' && curl -sk https://lab.local/api/notes && sudo -u postgres psql -d webappdb -c 'SELECT * FROM notes ORDER BY id DESC LIMIT 5;'`)*

---

## 3.2. Bảo mật Cơ sở dữ liệu và Quản lý Thông tin Nhạy cảm

### Áp dụng nguyên tắc đặc quyền tối thiểu (`configs/vm1/db/setup.sql`, `app/schema.sql`)
Ứng dụng không dùng tài khoản siêu quản trị `postgres` mà sử dụng role riêng `webapp_user` trên database riêng `webappdb`:

| Thành phần | Quyền / Thuộc tính đã cấu hình | Mục đích bảo mật |
| :--- | :--- | :--- |
| Role `webapp_user` | `LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOINHERIT` | Chỉ được đăng nhập; không có quyền quản trị cluster, tạo DB mới, tạo role khác hay replication. |
| Database `webappdb` | `REVOKE ALL ON DATABASE webappdb FROM PUBLIC; GRANT CONNECT ... TO webapp_user;` | Chặn các role khác trong PostgreSQL kết nối trái phép vào `webappdb`. |
| Schema `public` | `REVOKE ALL ON SCHEMA public FROM PUBLIC; GRANT USAGE, CREATE ... TO webapp_user;` | Thu hồi quyền mặc định của `PUBLIC`; chỉ cho phép `webapp_user` thao tác trong phạm vi `webappdb`. |
| Bảng `notes` & `notes_id_seq` | `ALTER TABLE notes OWNER TO webapp_user; GRANT SELECT, INSERT, UPDATE, DELETE ...; GRANT USAGE, SELECT ON SEQUENCE ...;` | Đảm bảo dù `schema.sql` được nạp bằng `postgres`, ứng dụng vẫn đọc/ghi được và không cần quyền `postgres`. |

*Ghi chú thiết kế:* Sở dĩ `webapp_user` được gán làm chủ sở hữu `webappdb`/`notes` và giữ quyền `USAGE, CREATE` trên schema `public` trong phạm vi `webappdb` là để hai kịch bản `scripts/backup.sh` (`pg_dump --clean --if-exists`) và `scripts/restore.sh` (`psql -U "$DB_USER"`) có thể xóa/tạo lại bảng `notes` khi diễn tập khôi phục thảm họa mà không cần dùng tài khoản `postgres`. Trong môi trường production quy mô lớn, nhóm có thể tách thêm một role chỉ có `SELECT/INSERT/UPDATE/DELETE` cho runtime của app và một role riêng cho tác vụ migrate/restore.

### Cô lập mạng PostgreSQL chỉ lắng nghe `127.0.0.1:5432`
PostgreSQL trên VM1 được khóa chặt ở hai lớp cấu hình (kết hợp tường lửa UFW không mở cổng `5432` và `8000` ra ngoài):
1. **`configs/vm1/db/postgresql-bind.conf`** (nạp vào `/etc/postgresql/14/main/conf.d/99-localhost.conf`): thiết lập `listen_addresses = '127.0.0.1'`, `port = 5432` và `password_encryption = 'scram-sha-256'` để socket TCP chỉ gắn trên giao diện loopback thay vì `0.0.0.0`.
2. **`configs/vm1/db/pg_hba.conf`** (đặt tại `/etc/postgresql/14/main/pg_hba.conf`): chỉ cho phép xác thực `peer` qua Unix socket cục bộ (`local`) cho quản trị viên trên máy và xác thực `scram-sha-256` qua loopback (`127.0.0.1/32`, `::1/128`) dành riêng cho cặp `webappdb` / `webapp_user`. Mọi kết nối từ dải mạng ngoài hoặc đăng nhập `postgres` qua TCP đều bị từ chối.

### Quản lý bí mật bằng `EnvironmentFile` (`/etc/webapp/app.env`)
Toàn bộ thông số kết nối (`DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`) được tách khỏi mã nguồn sang tệp `/etc/webapp/app.env` (`chown root:root`, `chmod 600` trong thư mục `/etc/webapp` quyền `750`). Trên Git chỉ lưu tệp mẫu `app/.env.example`.

Cơ chế này tương thích đồng thời cho cả hai luồng vận hành:
- **`systemd` (`webapp.service`):** Tiến trình PID 1 đọc `/etc/webapp/app.env` dưới quyền `root` trước khi hạ đặc quyền xuống `User=webapp`, do đó `webapp` vẫn nhận được biến môi trường dù không có quyền đọc trực tiếp tệp `app.env` (`600`) trên ổ đĩa.
- **Bộ công cụ Bash (`scripts/lib/common.sh`):** Hàm `load_env()` của `backup.sh` và `restore.sh` (chạy qua `sudo`) dùng chung ngay tệp `/etc/webapp/app.env` này mà không phải nhân bản mật khẩu ở nhiều nơi.

> **[CHÈN ẢNH BẰNG CHỨNG 2 — Chụp trên VM1 Ubuntu 22.04]**  
> ![Cô lập cổng localhost và phân quyền app.env](../images/tv3_02_db_localhost_env.png)  
> *Hình 3.2: Đầu ra `ss -tlpn` chứng minh `gunicorn` (`127.0.0.1:8000`) và `postgres` (`127.0.0.1:5432`) chỉ lắng nghe nội bộ, kèm `ls -l /etc/webapp/app.env` xác nhận quyền `600` (`-rw-------`).*  
> *(Lệnh gợi ý khi chụp trên VM1: `sudo ss -tlpn | grep -E '(:8000|:5432)\b' && sudo ls -la /etc/webapp/app.env`)*

---

## 3.3. Quản lý Dịch vụ Ứng dụng bằng Systemd (`webapp.service`)

Tệp cấu hình `configs/vm1/systemd/webapp.service` (cài đặt tại `/etc/systemd/system/webapp.service`) điều khiển vòng đời tiến trình Gunicorn như một dịch vụ hệ thống chuẩn:

| Chỉ thị | Giá trị cấu hình | Vai trò kỹ thuật |
| :--- | :--- | :--- |
| `After=` / `Wants=` | `network.target postgresql.service` | Đảm bảo mạng và PostgreSQL được khởi chạy trước khi ứng dụng mở kết nối. |
| `Type=` | `simple` | Phù hợp với Gunicorn chạy foreground (`--daemon` không bật), giúp `systemd` theo dõi chính xác PID tiến trình chính. |
| `User=` / `Group=` | `webapp` / `webapp` | Chạy tiến trình ứng dụng bằng tài khoản hệ thống không có shell đăng nhập (`/usr/sbin/nologin`), giới hạn thiệt hại nếu ứng dụng bị khai thác. |
| `WorkingDirectory=` | `/opt/webapp` | Đặt thư mục làm việc để Gunicorn nạp đúng module `app:app`. |
| `EnvironmentFile=` | `/etc/webapp/app.env` | Nạp biến kết nối CSDL bảo mật vào tiến trình mà không hard-code vào unit file hay mã nguồn. |
| `ExecStart=` | `/opt/webapp/venv/bin/gunicorn --workers 2 --bind 127.0.0.1:8000 --access-logfile - --error-logfile - app:app` | Khởi chạy 2 worker lắng nghe chặt trên `127.0.0.1:8000`, xuất cả access log và error log ra `stdout`/`stderr`. |
| `Restart=` / `RestartSec=` | `on-failure` / `3` | Tự động khởi động lại dịch vụ sau 3 giây khi tiến trình thoát bất thường (ví dụ bị `SIGKILL` / `kill -9`), nhưng không lặp vô tận nếu tắt chủ động qua `systemctl stop`. |
| `StandardOutput=` / `StandardError=` / `SyslogIdentifier=` | `journal` / `journal` / `webapp` | Gom toàn bộ nhật ký vận hành về `systemd-journald`, dễ truy vấn qua `journalctl -u webapp.service`. |
| `NoNewPrivileges=` / `PrivateTmp=` | `true` / `true` | Gia cố dịch vụ: ngăn tiến trình nâng đặc quyền và cấp không gian `/tmp` riêng biệt. |

Khi kiểm thử sự cố bằng cách gửi tín hiệu `kill -9` (hoặc `pkill -9 -f gunicorn`) vào tiến trình chính, `systemd` ghi nhận trạng thái thoát `code=killed, status=9/KILL`, tự động kích hoạt chu kỳ khởi động lại sau `RestartSec=3` với PID mới và khôi phục phản hồi `HTTP 200` tại `/health`.

> **[CHÈN ẢNH BẰNG CHỨNG 3 — Chụp trên VM1 Ubuntu 22.04]**  
> ![Trạng thái systemd và khả năng tự phục hồi sau kill -9](../images/tv3_03_systemd_autorestart.png)  
> *Hình 3.3: `systemctl status webapp.service` hiển thị `active (running)` và `enabled`, cùng log `journalctl -u webapp.service` chứng minh dịch vụ tự khởi động lại sau sự cố `kill -9`.*  
> *(Lệnh gợi ý khi chụp trên VM1: `sudo pkill -9 -f gunicorn; sleep 4; systemctl status webapp.service --no-pager; journalctl -u webapp.service -n 25 --no-pager`)*

---

## 3.4. Điểm Phối hợp Tích hợp với Các Thành phần Khác

| Thành viên liên kết | Giao diện phối hợp |
| :--- | :--- |
| **Thành viên 1 (Hạ tầng & Bảo mật)** | Đồng bộ user `webapp:webapp`, phân quyền `/opt/webapp` và `/etc/webapp/app.env` (`600`), xác nhận UFW chặn hoàn toàn cổng `8000` và `5432` từ bên ngoài. |
| **Thành viên 2 (Nginx & Deploy)** | Cố định đích proxy `127.0.0.1:8000`, endpoint kiểm tra `GET /health`, và tên unit `webapp.service` cho `scripts/deploy.sh`. |
| **Thành viên 4 (Backup, Restore & Monitor)** | Khóa cứng bộ biến `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` trong `/etc/webapp/app.env`, cổng `5432` và service `webapp` cho `backup.sh`, `restore.sh`, `health-check.sh`. |
