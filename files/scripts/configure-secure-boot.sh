#!/usr/bin/env bash
set -euo pipefail

# Keep secureblue's enrollment flow, using the key that signs our OpenRazer modules.
python3 - <<'PY'
from pathlib import Path

changes = {
    "/usr/libexec/secureblue/enroll_secure_boot_keys.py": {
        'AKMODS_DER_PATH = "/usr/share/pki/akmods/certs/akmods-secureblue.der"':
            'AKMODS_DER_PATH = "/usr/share/pki/akmods/certs/akmods-ublue.der"',
        '"The secureblue MOK is already enrolled."':
            '"The Universal Blue MOK is already enrolled."',
        'password="secureblue"': 'password="universalblue"',
        '"The secureblue MOK has been queued for enrollment.':
            '"The Universal Blue MOK has been queued for enrollment.',
        "password 'secureblue'": "password 'universalblue'",
    },
    "/usr/share/bluebuild/justfiles/common/wrappers.just": {
        "alias enroll-secureblue-secure-boot-key := enroll-secure-boot-keys":
            "alias enroll-secure-boot-key := enroll-secure-boot-keys",
    },
    "/usr/libexec/secureblue/securebluesecurebootnotify": {
        "Secure Boot key is not enrolled!": "Universal Blue Secure Boot key is not enrolled!",
        "https://secureblue.dev/faq#new-key":
            "https://docs.bazzite.gg/General/Installation_Guide/secure_boot/",
    },
}
for filename, replacements in changes.items():
    path = Path(filename)
    source = path.read_text()
    for old, new in replacements.items():
        if source.count(old) != 1:
            raise SystemExit(f"Expected one {old!r} in {filename}")
        source = source.replace(old, new)
    path.write_text(source)
PY
