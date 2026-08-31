#!/usr/bin/env bash
set -euo pipefail

launcher=/usr/libexec/nocblue/file-manager-launcher
real_dir=/usr/libexec/nocblue/file-managers

[[ -x "${launcher}" ]] || {
    printf 'missing file-manager launcher: %s\n' "${launcher}" >&2
    exit 1
}

install -d -m 0755 "${real_dir}"

for app in nautilus thunar; do
    source_path="/usr/bin/${app}"
    real_path="${real_dir}/${app}"

    [[ -x "${source_path}" && ! -L "${source_path}" ]] || {
        printf 'missing native file-manager executable: %s\n' "${source_path}" >&2
        exit 1
    }
    install -m 0755 "${source_path}" "${real_path}"
    rm -f "${source_path}"
    ln -s ../libexec/nocblue/file-manager-launcher "${source_path}"
done

test -L /usr/bin/Thunar
test "$(readlink /usr/bin/Thunar)" = thunar

# Nautilus remains the org.freedesktop.FileManager1 activation owner. Thunar
# stays launchable explicitly without racing Nautilus for the shared D-Bus name.
rm -f /usr/share/dbus-1/services/org.xfce.Thunar.FileManager1.service
