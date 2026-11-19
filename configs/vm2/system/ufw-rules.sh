#!/usr/bin/env bash
# Luật UFW cho VM2 (TV1): chỉ cho SSH từ VM1 (và máy admin nếu dùng bastion).
set -euo pipefail
VM1_IP="<IP-VM1>"
ufw default deny incoming
ufw default allow outgoing
ufw allow from "$VM1_IP" to any port 2222 proto tcp comment 'rsync/ssh từ VM1'
ufw --force enable
