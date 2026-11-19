# Dùng: make lint | make package MSSV=MSSV1_MSSV2_MSSV3_MSSV4
MSSV ?= MSSV1_MSSV2_MSSV3_MSSV4
lint:
	shellcheck -x scripts/*.sh scripts/lib/*.sh
package:
	tar --exclude-vcs --exclude='.github' --exclude='app.env' -czf ../$(MSSV).tar.gz -C .. $(notdir $(CURDIR))
	@echo "Đã tạo ../$(MSSV).tar.gz"
