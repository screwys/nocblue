#!/usr/bin/env python3
import json
import os
import re
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path

import yaml


def inspect(reference):
    return json.loads(subprocess.check_output([
        'skopeo', 'inspect', '--override-arch', 'amd64', f'docker://{reference}',
    ], text=True))


def has_openrazer(reference):
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run([
            'skopeo', 'copy', '-q', '--override-arch', 'amd64',
            f'docker://{reference}', f'dir:{tmp}',
        ], check=True, stdout=subprocess.DEVNULL)
        manifest = json.loads(Path(tmp, 'manifest.json').read_text())
        names = set()
        for layer in manifest['layers']:
            with tarfile.open(Path(tmp, layer['digest'].split(':', 1)[1]), 'r|*') as tar:
                names.update(member.name for member in tar)
    return (any(n.startswith('rpms/common/openrazer-') for n in names)
            and any(n.startswith('rpms/kmods/kmod-openrazer-') for n in names))


base = 'ghcr.io/secureblue/silverblue-main-hardened'
image = inspect(f'{base}:latest')
release = image['Labels']['org.opencontainers.image.version'].split('.')[0]

# Universal Blue skips OpenRazer when it fails to build for a kernel, so take
# the newest kernel whose akmods image still carries the signed OpenRazer pair.
akmods_repo = 'ghcr.io/ublue-os/akmods'
kernel_tag = re.compile(rf'main-{release}-(\d[\w.]*-\d[\w.]*\.fc{release})')
kernel_tags = sorted(
    (m.group(0) for tag in inspect(f'{akmods_repo}:main-{release}')['RepoTags']
     if (m := kernel_tag.fullmatch(tag))),
    key=lambda tag: [int(n) for n in re.findall(r'\d+', kernel_tag.fullmatch(tag).group(1))],
    reverse=True,
)
for tag in kernel_tags:
    kernel_image = f"{akmods_repo}@{inspect(f'{akmods_repo}:{tag}')['Digest']}"
    if has_openrazer(kernel_image):
        print(f'Using {tag} ({kernel_image})', file=sys.stderr)
        break
    print(f'Skipping {tag}: no OpenRazer RPMs', file=sys.stderr)
else:
    sys.exit(f'No {akmods_repo}:main-{release} kernel image carries OpenRazer')
build_tag = f"build-{os.environ['GITHUB_RUN_ID']}"
event = json.loads(Path(os.environ['GITHUB_EVENT_PATH']).read_text())
branch = os.environ['GITHUB_REF_NAME'].replace('/', '_')
image_tag = build_tag
if os.environ['GITHUB_REF_NAME'] != event['repository']['default_branch']:
    image_tag = f'br-{branch}-{build_tag}-{release}'

recipe = yaml.safe_load(Path('recipes/recipe.yml').read_text())
recipe['image-version'] = f"latest@{image['Digest']}"
recipe['alt-tags'] = [build_tag]
for module in recipe['modules']:
    if module['type'] == 'containerfile':
        module['snippets'] = [
            re.sub(r'ghcr.io/ublue-os/akmods:main-[0-9]+', kernel_image, snippet)
            for snippet in module['snippets']
        ]
Path('recipes/recipe-build.yml').write_text(yaml.safe_dump(recipe, sort_keys=False))
with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
    output.write(f'fedora_release={release}\nimage_tag={image_tag}\n')
print(f'Stable Fedora {release}: {base}:latest@{image["Digest"]}')
print(f'Kernel/OpenRazer payload: {kernel_image}')
