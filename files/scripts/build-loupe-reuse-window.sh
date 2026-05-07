#!/usr/bin/env bash
set -euo pipefail

loupe_version="$(rpm -q --qf '%{VERSION}' loupe)"
workdir="$(mktemp -d /tmp/nocblue-loupe-build-XXXXXX)"

cleanup() {
    rm -rf "${workdir}"
}
trap cleanup EXIT

dnf -y install --setopt=install_weak_deps=False \
    meson \
    blueprint-compiler \
    desktop-file-utils \
    appstream \
    gettext-devel \
    yelp-tools \
    libadwaita-devel \
    gtk4-devel \
    libgweather-devel \
    lcms2-devel \
    libseccomp-devel

curl -L --fail \
    "https://gitlab.gnome.org/GNOME/loupe/-/archive/${loupe_version}/loupe-${loupe_version}.tar.gz" \
    -o "${workdir}/loupe.tar.gz"

tar -xf "${workdir}/loupe.tar.gz" -C "${workdir}"
srcdir="${workdir}/loupe-${loupe_version}"

python3 - "${srcdir}/src/application.rs" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
old = """        fn open(&self, files: &[gio::File], _hint: &str) {
            tracing::debug!("Open {} file(s)", files.len());
            let application = self.obj();
            let win = LpWindow::new(&*application);
            win.image_view().set_images_from_files(files.to_vec());
        }
"""
new = """        fn open(&self, files: &[gio::File], _hint: &str) {
            tracing::debug!("Open {} file(s)", files.len());
            let application = self.obj();
            let win = application
                .active_window()
                .and_then(|window| window.downcast::<LpWindow>().ok())
                .unwrap_or_else(|| LpWindow::new(&*application));

            tracing::debug!("nocblue: reusing active Loupe window for open");
            win.image_view().set_images_from_files(files.to_vec());
            win.present();
        }
"""
if text.count(old) != 1:
    raise SystemExit("Loupe open handler changed; update nocblue patch")
path.write_text(text.replace(old, new), encoding="utf-8")
PY

meson setup "${srcdir}/build" "${srcdir}" \
    --prefix=/usr \
    -Dprofile=release \
    -Dx11=disabled
meson compile -C "${srcdir}/build"
meson install -C "${srcdir}/build"

install -D -m 0644 /dev/null /usr/share/nocblue/media-patches/loupe-reuse-active-window.patch-applied

dnf -y remove \
    meson \
    blueprint-compiler \
    desktop-file-utils \
    appstream \
    gettext-devel \
    yelp-tools \
    libadwaita-devel \
    gtk4-devel \
    libgweather-devel \
    lcms2-devel \
    libseccomp-devel || true
dnf -y clean all
