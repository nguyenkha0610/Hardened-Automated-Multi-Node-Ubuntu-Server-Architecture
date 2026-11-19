#!/usr/bin/env bash
# Tạo chứng chỉ tự ký (TV2). Lý do không dùng Let's Encrypt: xem docs/REPORT_OUTLINE.md mục TLS.
set -euo pipefail
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/lab-selfsigned.key \
    -out /etc/ssl/certs/lab-selfsigned.crt \
    -subj "/C=VN/ST=HCMC/O=HCMUS-Lab/CN=lab.local" \
    -addext "subjectAltName=DNS:lab.local,DNS:status.lab.local"
chmod 600 /etc/ssl/private/lab-selfsigned.key
