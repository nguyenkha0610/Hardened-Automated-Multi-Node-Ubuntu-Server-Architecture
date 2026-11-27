"""Ứng dụng web Flask kết nối PostgreSQL: GET /, GET /health, GET/POST /api/notes."""
from contextlib import contextmanager
import logging
import os
import sys

from flask import Flask, jsonify, render_template_string, request
import psycopg2
from werkzeug.middleware.proxy_fix import ProxyFix

logging.basicConfig(
    stream=sys.stdout,
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)

app = Flask(__name__)
# Tin cậy header X-Forwarded-* do Nginx reverse proxy gửi sang (1 hop).
app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1)

gunicorn_logger = logging.getLogger("gunicorn.error")
if gunicorn_logger.handlers:
    app.logger.handlers = gunicorn_logger.handlers
    app.logger.setLevel(gunicorn_logger.level)

MAX_CONTENT_LEN = 500

INDEX_HTML = """<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Hệ thống Ghi chú — Linux Lab</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 720px; margin: 2rem auto; padding: 0 1rem; color: #1f2937; }
    h1 { font-size: 1.5rem; margin-bottom: 0.25rem; }
    p.sub { color: #4b5563; margin-top: 0; }
    form { display: flex; gap: 0.5rem; margin: 1.25rem 0; }
    input[type="text"] { flex: 1; padding: 0.55rem 0.75rem; border: 1px solid #d1d5db; border-radius: 6px; font-size: 1rem; }
    button { padding: 0.55rem 1rem; border: 0; border-radius: 6px; background: #2563eb; color: #fff; font-size: 1rem; cursor: pointer; }
    button:hover { background: #1d4ed8; }
    #status { min-height: 1.25rem; font-size: 0.9rem; color: #b91c1c; margin-bottom: 0.75rem; }
    ul { list-style: none; padding: 0; margin: 0; }
    li { padding: 0.65rem 0.85rem; border: 1px solid #e5e7eb; border-radius: 6px; margin-bottom: 0.5rem; background: #f9fafb; }
    .meta { font-size: 0.8rem; color: #6b7280; margin-top: 0.25rem; }
  </style>
</head>
<body>
  <h1>Quản lý Ghi chú</h1>
  <p class="sub">Nginx (HTTPS) &rarr; Flask/gunicorn (127.0.0.1:8000) &rarr; PostgreSQL (127.0.0.1:5432)</p>
  <form id="note-form">
    <input id="content" name="content" type="text" maxlength="500" placeholder="Nhập nội dung ghi chú..." required>
    <button type="submit">Lưu</button>
  </form>
  <div id="status"></div>
  <ul id="notes"></ul>
  <script>
    const listEl = document.getElementById("notes");
    const statusEl = document.getElementById("status");
    const formEl = document.getElementById("note-form");
    const inputEl = document.getElementById("content");

    async function loadNotes() {
      statusEl.textContent = "";
      try {
        const res = await fetch("/api/notes");
        const data = await res.json();
        if (!res.ok) throw new Error(data.error || "Không tải được dữ liệu");
        listEl.innerHTML = "";
        for (const item of data) {
          const li = document.createElement("li");
          const body = document.createElement("div");
          body.textContent = item.content;
          const meta = document.createElement("div");
          meta.className = "meta";
          meta.textContent = "#" + item.id + " · " + item.created_at;
          li.appendChild(body);
          li.appendChild(meta);
          listEl.appendChild(li);
        }
      } catch (err) {
        statusEl.textContent = err.message;
      }
    }

    formEl.addEventListener("submit", async (e) => {
      e.preventDefault();
      const content = inputEl.value.trim();
      if (!content) return;
      statusEl.textContent = "";
      try {
        const res = await fetch("/api/notes", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ content })
        });
        const data = await res.json();
        if (!res.ok) throw new Error(data.error || "Lỗi lưu ghi chú");
        inputEl.value = "";
        await loadNotes();
      } catch (err) {
        statusEl.textContent = err.message;
      }
    });

    loadNotes();
  </script>
</body>
</html>
"""


@contextmanager
def db_cursor():
    """Mở kết nối PostgreSQL từ EnvironmentFile, tự commit/rollback và luôn đóng kết nối."""
    conn = psycopg2.connect(
        host=os.environ["DB_HOST"],
        port=os.environ.get("DB_PORT", "5432"),
        dbname=os.environ["DB_NAME"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        connect_timeout=5,
    )
    try:
        with conn.cursor() as cur:
            yield cur
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


@app.get("/")
def index():
    """Trang web tối giản kiểm chứng luồng Nginx -> Flask -> PostgreSQL không phụ thuộc CDN ngoài."""
    return render_template_string(INDEX_HTML)


@app.get("/health")
def health():
    """Endpoint kiểm tra sức khỏe phục vụ deploy.sh và giám sát."""
    try:
        with db_cursor() as cur:
            cur.execute("SELECT 1")
        return jsonify(status="ok"), 200
    except psycopg2.Error as exc:
        app.logger.error("Health check database error: %s", exc)
        return jsonify(status="error", database="unavailable"), 503


@app.get("/api/notes")
def list_notes():
    """Trả về tối đa 50 ghi chú mới nhất từ PostgreSQL."""
    try:
        with db_cursor() as cur:
            cur.execute(
                "SELECT id, content, created_at FROM notes ORDER BY id DESC LIMIT 50"
            )
            rows = [
                {"id": r[0], "content": r[1], "created_at": r[2].isoformat()}
                for r in cur.fetchall()
            ]
        return jsonify(rows), 200
    except psycopg2.Error as exc:
        app.logger.error("Database read error on GET /api/notes: %s", exc)
        return jsonify(error="database unavailable"), 503


@app.post("/api/notes")
def add_note():
    """Thêm ghi chú mới vào PostgreSQL từ JSON body hoặc form field."""
    payload = request.get_json(silent=True)
    if isinstance(payload, dict):
        raw_content = payload.get("content", "")
    else:
        raw_content = request.form.get("content", "")

    content = raw_content.strip() if isinstance(raw_content, str) else ""
    if not content:
        return jsonify(error="content is required"), 400
    if len(content) > MAX_CONTENT_LEN:
        return jsonify(error=f"content must be <= {MAX_CONTENT_LEN} characters"), 400

    try:
        with db_cursor() as cur:
            cur.execute(
                "INSERT INTO notes (content) VALUES (%s) RETURNING id, content, created_at",
                (content,),
            )
            note_id, saved_content, created_at = cur.fetchone()
        app.logger.info("created note id=%s from ip=%s", note_id, request.remote_addr)
        return (
            jsonify(
                id=note_id,
                content=saved_content,
                created_at=created_at.isoformat(),
            ),
            201,
        )
    except psycopg2.Error as exc:
        app.logger.error("Database write error on POST /api/notes: %s", exc)
        return jsonify(error="database unavailable"), 503


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=8000)
