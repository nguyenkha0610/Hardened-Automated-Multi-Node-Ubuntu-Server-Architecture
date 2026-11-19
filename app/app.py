"""Ứng dụng mẫu: GET /api/notes (đọc), POST /api/notes (ghi), GET /health."""
import os
import sys
import logging
import psycopg2
from flask import Flask, jsonify, request

logging.basicConfig(stream=sys.stdout, level=logging.INFO)  # -> journald
app = Flask(__name__)


def get_conn():
    # Bí mật lấy từ biến môi trường (EnvironmentFile), KHÔNG hard-code
    return psycopg2.connect(
        host=os.environ["DB_HOST"], port=os.environ.get("DB_PORT", "5432"),
        dbname=os.environ["DB_NAME"], user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
    )


@app.get("/health")
def health():
    with get_conn() as c, c.cursor() as cur:
        cur.execute("SELECT 1")
    return jsonify(status="ok")


@app.get("/api/notes")
def list_notes():
    with get_conn() as c, c.cursor() as cur:
        cur.execute("SELECT id, content, created_at FROM notes ORDER BY id DESC LIMIT 50")
        rows = [{"id": r[0], "content": r[1], "created_at": r[2].isoformat()} for r in cur.fetchall()]
    return jsonify(rows)


@app.post("/api/notes")
def add_note():
    content = (request.get_json(silent=True) or {}).get("content", "").strip()
    if not content:
        return jsonify(error="content is required"), 400
    with get_conn() as c, c.cursor() as cur:
        cur.execute("INSERT INTO notes (content) VALUES (%s) RETURNING id", (content,))
        new_id = cur.fetchone()[0]
    app.logger.info("created note id=%s", new_id)
    return jsonify(id=new_id), 201


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=8000)
