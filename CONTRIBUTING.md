# Quy trình Git của nhóm

## Nhánh
- `main`: chỉ chứa bản đã test, dùng để ghép lên VM demo. **Không push trực tiếp.**
- `tv1/infra-security`, `tv2/nginx-deploy`, `tv3/app-db`, `tv4/backup-monitor`: mỗi người làm trên nhánh riêng.

## Luồng làm việc
```bash
git checkout -b tv2/nginx-deploy
# ... code, test trên VM cá nhân ...
git add configs/vm1/nginx scripts/deploy.sh
git commit -m "feat(nginx): thêm vhost status + redirect 80->443"
git push -u origin tv2/nginx-deploy   # rồi mở Pull Request vào main
```
- Mỗi PR cần **ít nhất 1 người review** (TV4 review chéo script của TV2).
- CI (`.github/workflows/shellcheck.yml`) phải xanh mới merge.

## Quy ước commit
`feat|fix|docs|chore(<phạm vi>): <mô tả>` – ví dụ `fix(backup): xóa bản cũ hơn 7 ngày`.

## Quy tắc bắt buộc
1. **Không commit** mật khẩu, `app.env`, `*.key`. Chỉ commit `*.example`.
2. Mọi script: `#!/usr/bin/env bash`, `set -euo pipefail`, `trap` ERR/EXIT, `--help`, ghi log, **shellcheck sạch**.
3. File trong `configs/` là file **thật** đang chạy trên VM (đồng bộ lại nếu sửa trên VM).
4. Mỗi bằng chứng (ảnh chụp) đặt trong `docs/evidence/` theo tên `<mục>-<mô-tả>.png`.
