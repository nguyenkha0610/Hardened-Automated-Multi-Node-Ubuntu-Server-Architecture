-- Lược đồ bảng dữ liệu ứng dụng ghi chú (nạp vào database webappdb).
CREATE TABLE IF NOT EXISTS notes (
    id         SERIAL PRIMARY KEY,
    content    TEXT NOT NULL CHECK (char_length(content) <= 500),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Đảm bảo webapp_user sở hữu bảng và sequence dù schema.sql được nạp bằng tài khoản postgres.
ALTER TABLE notes OWNER TO webapp_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE notes TO webapp_user;
GRANT USAGE, SELECT ON SEQUENCE notes_id_seq TO webapp_user;
