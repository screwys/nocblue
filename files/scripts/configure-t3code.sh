#!/usr/bin/env bash
set -euo pipefail
umask 022

appdir=/usr/lib64/t3code-nightly
workdir="$(mktemp -d /tmp/t3code.XXXXXX)"
trap 'rm -rf "$workdir"' EXIT

# Keep Electron's Node ABI for the backend without its namespace permissions.
cp --reflink=auto "${appdir}/t3code" "${appdir}/t3code.node"
mv "${appdir}/t3code" "${appdir}/t3code.bin"
install -m 0755 /usr/share/nocblue/launchers/t3code-nightly "${appdir}/t3code"
chmod 0755 "${appdir}/chrome-sandbox"

npm install --prefix "$workdir" --cache "${workdir}/npm-cache" --ignore-scripts --no-audit --no-fund \
    @electron/asar@4.3.1 @electron/fuses@2.1.3
node --input-type=module - "$workdir" "$appdir" <<'JS'
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { Readable } from 'node:stream';
import { pathToFileURL } from 'node:url';

const [workdir, appdir] = process.argv.slice(2);
const asar = await import(pathToFileURL(`${workdir}/node_modules/@electron/asar/lib/asar.js`));
const { flipFuses, FuseVersion, FuseV1Options, FuseState, getCurrentFuseWire } = await import(pathToFileURL(`${workdir}/node_modules/@electron/fuses/dist/index.js`));
// Only the unprivileged backend copy may run arbitrary Node programs.
await flipFuses(`${appdir}/t3code.bin`, {
    version: FuseVersion.V1,
    [FuseV1Options.RunAsNode]: false,
    [FuseV1Options.EnableNodeCliInspectArguments]: false,
});
const fuses = await getCurrentFuseWire(`${appdir}/t3code.bin`);
assert.equal(fuses[FuseV1Options.RunAsNode], FuseState.DISABLE);
assert.equal(fuses[FuseV1Options.EnableNodeCliInspectArguments], FuseState.DISABLE);
const archive = `${appdir}/resources/app.asar`;
const names = asar.listPackage(archive).map(name => name.replace(/^\//, ''));
const boot = JSON.parse(asar.extractFile(archive, 'package.json')).main;
const streams = [];
const unpacked = [];
for (const name of names) {
    const entry = asar.statFile(archive, name, false);
    const common = { path: name, unpacked: entry.unpacked === true };
    if (entry.files) {
        streams.push({ ...common, type: 'directory' });
    } else if (entry.link) {
        streams.push({ ...common, type: 'link', symlink: path.relative(path.dirname(name), entry.link), stat: { mode: 0o777 } });
    } else {
        // Terra removes foreign-architecture files without changing the header.
        if (entry.unpacked && !fs.existsSync(`${archive}.unpacked/${name}`)) continue;
        if (entry.unpacked) unpacked.push(name);
        // Backend spawns, URL handlers, and relaunches return through the launcher.
        const patchedBoot = name === boot
            ? Buffer.from(`process.execPath = ${JSON.stringify(`${appdir}/t3code`)};\n` + asar.extractFile(archive, name))
            : undefined;
        streams.push({
            ...common, type: 'file',
            stat: { size: patchedBoot?.length ?? entry.size, mode: entry.executable ? 0o755 : 0o644 },
            streamGenerator: () => Readable.from(patchedBoot ?? asar.extractFile(archive, name)),
        });
    }
}
const patched = `${workdir}/app.asar`;
await asar.createPackageFromStreams(patched, streams);
const actualUnpacked = asar.listPackage(patched).map(name => name.replace(/^\//, '')).filter(name => {
    const entry = asar.statFile(patched, name, false);
    return !entry.files && entry.unpacked;
});
assert.deepEqual(actualUnpacked.sort(), unpacked.sort());
fs.copyFileSync(patched, archive);
fs.chmodSync(archive, 0o644);
fs.rmSync(`${archive}.unpacked`, { recursive: true });
fs.cpSync(`${patched}.unpacked`, `${archive}.unpacked`, { recursive: true });
JS
