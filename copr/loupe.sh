#!/usr/bin/env bash
# COPR custom source script for the loupe package in screwyy/nocblue.
#
# Takes Fedora's Loupe packaging for the release of the chroot this script
# runs in and adds the window-reuse patch. The release gets a ".1" suffix, so
# this build outranks Fedora's build of the same version and loses to any
# newer Fedora build. Rebuild after Fedora updates Loupe:
#   copr-cli build-package screwyy/nocblue --name loupe
set -euo pipefail

git clone --branch "f$(rpm -E '%fedora')" https://src.fedoraproject.org/rpms/loupe.git loupe
cd loupe

while read -r _ file _ hash; do
    file="${file#(}"
    file="${file%)}"
    curl -fsSL --retry 3 -o "${file}" \
        "https://src.fedoraproject.org/repo/pkgs/rpms/loupe/${file}/sha512/${hash}/${file}"
done <sources
sha512sum -c sources

cat >reuse-active-window.patch <<'EOF'
--- a/src/application.rs
+++ b/src/application.rs
@@ -93,8 +93,12 @@
         fn open(&self, files: &[gio::File], _hint: &str) {
             tracing::debug!("Open {} file(s)", files.len());
             let application = self.obj();
-            let win = LpWindow::new(&*application);
+            let win = application
+                .active_window()
+                .and_then(|window| window.downcast::<LpWindow>().ok())
+                .unwrap_or_else(|| LpWindow::new(&*application));
             win.image_view().set_images_from_files(files.to_vec());
+            win.present();
         }
     }

EOF

# Resolve %autorelease and %autochangelog from the dist-git history.
rpmautospec process-distgit loupe.spec loupe.spec

grep -q '^Release: *%autorelease$' loupe.spec
grep -q '^Source1:' loupe.spec
sed -i \
    -e 's/^\(Release: *%autorelease\)$/\1 -e 1/' \
    -e '/^Source1:/a Patch:          reuse-active-window.patch' \
    loupe.spec
