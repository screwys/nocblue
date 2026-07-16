#!/usr/bin/env bash
set -euo pipefail

os_release_sed="$(mktemp)"
cat >"${os_release_sed}" <<'EOF'
s|^NAME=.*|NAME="nocblue"|
s|^ID=.*|ID=nocblue|
s|^PRETTY_NAME=.*|PRETTY_NAME="nocblue 44"|
s|^CPE_NAME=.*|CPE_NAME="cpe:/o:nocblue:nocblue:44"|
s|^DEFAULT_HOSTNAME=.*|DEFAULT_HOSTNAME="desktop"|
s|^HOME_URL=.*|HOME_URL="https://github.com/screwys/nocblue"|
s|^DOCUMENTATION_URL=.*|DOCUMENTATION_URL="https://github.com/screwys/nocblue"|
s|^SUPPORT_URL=.*|SUPPORT_URL="https://github.com/screwys/nocblue/issues"|
s|^BUG_REPORT_URL=.*|BUG_REPORT_URL="https://github.com/screwys/nocblue/issues"|
s|^VARIANT=.*|VARIANT="nocblue"|
s|^VARIANT_ID=.*|VARIANT_ID=nocblue|
s|^IMAGE_ID=.*|IMAGE_ID="nocblue"|
EOF

for os_release in /usr/lib/os-release /usr/etc/os-release /etc/os-release; do
    [[ -f "${os_release}" && ! -L "${os_release}" ]] || continue
    sed -i -f "${os_release_sed}" "${os_release}"
done

rm -f "${os_release_sed}"

branding_dir=/usr/share/nocblue/branding

install -D -m 0644 \
    "${branding_dir}/silverblue-plymouth-watermark.png" \
    /usr/share/plymouth/themes/spinner/watermark.png
install -D -m 0644 \
    "${branding_dir}/silverblue-plymouth-watermark.png" \
    /usr/share/pixmaps/system-logo-white.png

rm -f \
    /usr/share/icons/hicolor/scalable/apps/start-here.svg \
    /usr/share/icons/hicolor/scalable/apps/start-here_classic.svg \
    /usr/share/icons/hicolor/scalable/places/start-here.svg

for size in 16 22 24 32 36 48 96 256; do
    for context in apps places; do
        icon_dir="/usr/share/icons/hicolor/${size}x${size}/${context}"
        install -d -m 0755 "${icon_dir}"
        magick "${branding_dir}/silverblue-start-here.png" \
            -filter Lanczos \
            -resize "${size}x${size}" \
            "${icon_dir}/start-here.png"
    done
done

rm -rf /usr/share/backgrounds/secureblue

printf 'desktop\n' >/etc/hostname
if [[ -f /etc/machine-info ]]; then
    if grep -q '^PRETTY_HOSTNAME=' /etc/machine-info; then
        sed -i 's|^PRETTY_HOSTNAME=.*|PRETTY_HOSTNAME=desktop|' /etc/machine-info
    else
        printf 'PRETTY_HOSTNAME=desktop\n' >>/etc/machine-info
    fi
else
    printf 'PRETTY_HOSTNAME=desktop\n' >/etc/machine-info
fi
