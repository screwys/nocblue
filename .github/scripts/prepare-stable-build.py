#!/usr/bin/env python3
import json
import os
import re
import subprocess
from pathlib import Path

import yaml


def inspect(reference):
    return json.loads(subprocess.check_output([
        'skopeo', 'inspect', '--override-arch', 'amd64', f'docker://{reference}',
    ], text=True))


base = 'ghcr.io/secureblue/silverblue-main-hardened'
image = inspect(f'{base}:latest')
release = image['Labels']['org.opencontainers.image.version'].split('.')[0]
akmods = inspect(f'ghcr.io/ublue-os/akmods:main-{release}')
kernel_image = f"ghcr.io/ublue-os/akmods@{akmods['Digest']}"
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
