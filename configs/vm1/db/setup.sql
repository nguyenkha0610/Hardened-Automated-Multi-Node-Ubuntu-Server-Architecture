-- Khởi tạo role đặc quyền tối thiểu và database riêng cho ứng dụng (TV3).
-- Chạy bằng quyền postgres: sudo -u postgres psql -f configs/vm1/db/setup.sql
-- Lưu ý: Đổi mật khẩu mạnh trước khi áp lên VM thật và đồng bộ vào /etc/webapp/app.env.

CREATE ROLE webapp_user WITH
    LOGIN
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    NOREPLICATION
    NOINHERIT
    PASSWORD 'CHANGE_ME_STRONG_PASSWORD';

CREATE DATABASE webappdb OWNER webapp_user;

-- Ở mức cluster/database: chặn PUBLIC, chỉ cấp quyền kết nối cho webapp_user.
REVOKE ALL ON DATABASE webappdb FROM PUBLIC;
GRANT CONNECT ON DATABASE webappdb TO webapp_user;

\c webappdb

-- Cô lập schema public khỏi PUBLIC; giữ USAGE, CREATE trong phạm vi webappdb để restore.sh (pg_dump --clean) chạy với webapp_user.
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE, CREATE ON SCHEMA public TO webapp_user;
