#!/usr/bin/env bash
# Luật UFW cho VM1 (TV1). Xuất trạng thái thật: sudo ufw status verbose > ufw-status.txt
set -euo pipefail
ufw default deny incoming
ufw default allow outgoing
ufw allow 2222/tcp comment 'SSH (cổng đã đổi)'
ufw allow 80/tcp   comment 'HTTP -> redirect sang HTTPS'
ufw allow 443/tcp  comment 'HTTPS'
# 8000 và 5432 KHÔNG mở: chỉ nghe trên 127.0.0.1
ufw --force enable
