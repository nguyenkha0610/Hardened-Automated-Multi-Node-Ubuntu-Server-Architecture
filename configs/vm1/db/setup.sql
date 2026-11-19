-- Chạy: sudo -u postgres psql -f setup.sql  (ĐỔI mật khẩu trước, đừng commit mật khẩu thật)
CREATE ROLE webapp_user LOGIN PASSWORD 'CHANGE_ME';
CREATE DATABASE webappdb OWNER webapp_user;
\c webappdb
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE, CREATE ON SCHEMA public TO webapp_user;
