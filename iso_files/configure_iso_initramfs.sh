#!/usr/bin/env bash
set -euo pipefail

ldconfig

# secureblue's ISO path includes libno_rlimit_as in the live initramfs because
# the hardened environment preloads it before the real root is fully up.
sed -i '/^install squashfs /d' /usr/lib/modprobe.d/secureblue.conf 2>/dev/null || :
cat >/etc/modprobe.d/zz-squashfs-override.conf <<'EOF'
install squashfs /sbin/modprobe --ignore-install squashfs
EOF

cat >/etc/dracut.conf.d/nocblue-libs.conf <<'EOF'
install_items+=" /usr/lib64/libno_rlimit_as.so /etc/ld.so.cache /etc/modprobe.d/zz-squashfs-override.conf "
EOF
