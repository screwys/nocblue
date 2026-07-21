#!/usr/bin/bash
# SPDX-License-Identifier: Apache-2.0
#
# Secureblue sets LD_PRELOAD globally through 40-hardened_malloc.conf. That is
# useful after switch-root, but early initramfs programs such as dracut hooks
# and systemd-cryptsetup must not inherit hardened_malloc. Mask the vendor
# drop-in only inside the generated initramfs.

check() {
    return 0
}

depends() {
    echo systemd
    return 0
}

install() {
    local confdir="${initdir}/etc/systemd/system.conf.d"

    mkdir -p "${confdir}"
    ln -sfn /dev/null "${confdir}/40-hardened_malloc.conf"
}
