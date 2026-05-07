# Bazzite performance and hardening comparison

This is an evidence-first comparison between nocblue and upstream Bazzite for
low-level performance, gaming, and hardening defaults. It intentionally avoids
"set this knob because a forum said so" tuning.

Compared Bazzite source:

- Repository: <https://github.com/ublue-os/bazzite>
- Commit: `aa7fef3858ee7f17d79b147c167cc6e9c6f83b4f`
- Commit date: `2026-05-06T18:56:07-07:00`
- Local checkout used for comparison: `/tmp/nocblue-bazzite-compare`

Compared nocblue source:

- Base: `ghcr.io/ublue-os/silverblue-main`, Fedora `44`
- Primary recipe: `recipes/recipe.yml`
- Explicit low-level config: `files/system/usr/lib/sysctl.d/55-nocblue-hardening.conf`

## Scope

Bazzite has several variants. This comparison uses the desktop shared Bazzite
configuration because nocblue targets strong desktop hardware rather than a
handheld/Steam Deck style power envelope. Steam Deck-specific Bazzite sysctls,
autologin, TDP, fan, display, and gamescope-session behavior are out of scope
unless explicitly called out.

Both projects inherit from the Universal Blue main family, but Bazzite layers a
custom gaming kernel, Valve-oriented Mesa and Xwayland stack, TuneD profiles,
storage scheduler rules, and gaming packages. nocblue currently stays closer to
the normal Universal Blue Silverblue base, then adds niri/Noctalia, native
development tools, browsers, selected gaming packages, and conservative
secureblue-inspired hardening.

## 1:1 sysctl comparison

| key | nocblue | Bazzite desktop explicit | judgment |
| --- | --- | --- | --- |
| `dev.tty.ldisc_autoload` | `0` | unset | Keep nocblue. Hardening; low desktop downside. |
| `fs.inotify.max_user_instances` | unset | `8192` | Good Bazzite carry-over for dev tools, editors, game launchers. |
| `fs.inotify.max_user_watches` | unset | `524288` | Good Bazzite carry-over. Memory cost is bounded by actual use. |
| `fs.protected_fifos` | `2` | unset | Keep nocblue. Hardening. |
| `fs.protected_hardlinks` | `1` | unset | Keep nocblue. Fedora may already default this, but explicit is fine. |
| `fs.protected_regular` | `2` | unset | Keep nocblue. Hardening. |
| `fs.protected_symlinks` | `1` | unset | Keep nocblue. Fedora may already default this, but explicit is fine. |
| `fs.suid_dumpable` | `0` | unset | Keep nocblue. Hardening. |
| `kernel.core_pattern` | `|/bin/false` | unset | Keep if the coredump policy is intentional. It hurts post-crash debugging. |
| `kernel.dmesg_restrict` | `1` | unset | Keep nocblue. Hardening. |
| `kernel.kptr_restrict` | `2` | unset | Keep nocblue. Hardening; may annoy kernel-level debugging. |
| `kernel.perf_event_paranoid` | `3` | unset | Keep for security, but consider an opt-in profiling helper. It blocks casual perf use. |
| `kernel.printk` | `3 3 3 3` | unset | Keep nocblue. Reduces console log noise/leakage. |
| `kernel.split_lock_mitigate` | unset | `0` | Do not blindly copy. It is performance/compatibility biased and weakens mitigation. |
| `kernel.sysrq` | `0` | unset by default; Bazzite has a user toggle | Keep nocblue default. Optional toggle is reasonable. |
| `kernel.unprivileged_bpf_disabled` | `1` | unset | Keep nocblue. Hardening. |
| `net.core.bpf_jit_harden` | `2` | unset | Keep nocblue. Hardening. |
| `net.ipv4.conf.all.accept_redirects` | `0` | unset | Keep nocblue. Hardening. |
| `net.ipv4.conf.all.accept_source_route` | `0` | unset | Keep nocblue. Hardening. |
| `net.ipv4.conf.all.rp_filter` | `1` | unset | Keep, unless VPN/multihoming issues appear. |
| `net.ipv4.conf.all.send_redirects` | `0` | unset | Keep nocblue. Hardening. |
| `net.ipv4.conf.default.accept_redirects` | `0` | unset | Keep nocblue. Hardening. |
| `net.ipv4.conf.default.accept_source_route` | `0` | unset | Keep nocblue. Hardening. |
| `net.ipv4.conf.default.rp_filter` | `1` | unset | Keep, unless VPN/multihoming issues appear. |
| `net.ipv4.conf.default.send_redirects` | `0` | unset | Keep nocblue. Hardening. |
| `net.ipv4.icmp_echo_ignore_broadcasts` | `1` | unset | Keep nocblue. Hardening. |
| `net.ipv4.icmp_ignore_bogus_error_responses` | `1` | unset | Keep nocblue. Hardening. |
| `net.ipv4.tcp_congestion_control` | unset | `bbr` | Candidate Bazzite carry-over. Useful for internet throughput/latency. |
| `net.ipv4.tcp_mtu_probing` | unset | `1` | Candidate Bazzite carry-over. Helps black-hole MTU paths; low risk. |
| `net.ipv4.tcp_rfc1337` | `1` | unset | Keep nocblue. Hardening. |
| `net.ipv4.tcp_syncookies` | `1` | unset | Keep nocblue. Usually already sane, explicit is okay. |
| `net.ipv6.conf.all.accept_redirects` | `0` | unset | Keep nocblue. Hardening. |
| `net.ipv6.conf.all.accept_source_route` | `0` | unset | Keep nocblue. Hardening. |
| `net.ipv6.conf.all.use_tempaddr` | `2` | `2` | Already aligned. |
| `net.ipv6.conf.default.accept_redirects` | `0` | unset | Keep nocblue. Hardening. |
| `net.ipv6.conf.default.accept_source_route` | `0` | unset | Keep nocblue. Hardening. |
| `net.ipv6.conf.default.use_tempaddr` | `2` | `2` | Already aligned. |
| `vm.max_map_count` | unset | `2147483642` | Strong Bazzite carry-over for gaming/Proton/dev workloads. |
| `vm.unprivileged_userfaultfd` | `0` | unset | Keep nocblue. Hardening. |

## Bazzite performance defaults missing from nocblue

### Kernel

Bazzite does not just tune the stock Fedora/Universal Blue kernel. It builds on
`ghcr.io/ublue-os/akmods` and installs a Bazzite kernel flavor. Current upstream
defaults show:

- `KERNEL_FLAVOR=ogc`
- `KERNEL_VERSION=6.19.14-ogc1.1.fc44.x86_64`
- README claims HDR, expanded hardware support, and gaming-related kernel
  patches.

nocblue currently documents the normal Fedora kernel and tests that normal
`kernel`, `kernel-core`, and `kernel-modules-core` are present while CachyOS is
absent.

Judgment: do not switch nocblue kernels casually. This is a major trust,
maintenance, Secure Boot, and regression-surface decision. For Radeon 7800 XT
desktop hardware, first harvest the lower-risk userspace/sysctl/TuneD items.

### Mesa, Xwayland, BlueZ, fwupd, and multimedia stack

Bazzite swaps or version-locks several low-level packages from its own repos and
Terra:

- Valve/patched Mesa via `terra-mesa`
- Bazzite/Valve-oriented `bluez`
- patched `xorg-x11-server-Xwayland`
- patched `fwupd`
- `mesa-libOpenCL`, `intel-opencl`, `clinfo`
- `libfreeaptx`
- `libbluray`, `makemkv`

nocblue uses Terra and RPM Fusion, but it does not do Bazzite's Mesa/Xwayland
swap/versionlock flow.

Judgment: this is high-value for gaming, but not a simple config knob. Treat it
as a separate image-design decision with build verification and rollback.

### Gaming packages

Bazzite installs a larger native gaming stack:

- Steam and Lutris as native packages
- `terra-gamescope` plus x86_64 and i686 gamescope libraries
- `umu-wrapper` and `umu-launcher`
- `vkBasalt` x86_64 and i686
- `MangoHud` x86_64 and i686
- OBS Vulkan capture hook libraries, x86_64 and i686
- `openxr`
- `steam-devices`, controller/input packages, and many hardware helpers

nocblue currently installs `steam-devices`, `gamescope`, `mangohud`,
`vulkan-tools`, `vkBasalt`, and optional `umu-launcher`, but not the same
multilib/native Steam/Lutris stack.

Judgment: if Steam/Lutris stay Flatpak-first in nocblue, do not blindly import
Bazzite's native package model. The i686 Vulkan/MangoHud/vkBasalt pieces may
still be worth checking if native gaming is expected.

### Memory and virtual memory behavior

Bazzite sets:

- `vm.max_map_count=2147483642`
- zram generator: `zstd`, size `min(ram / 2, 16384)`
- TuneD profile sysctls:
  - `vm.swappiness=180`
  - `vm.watermark_boost_factor=0`
  - `vm.watermark_scale_factor=125`
  - `vm.dirty_bytes=268435456`
  - `vm.dirty_background_bytes=134217728`
  - `vm.page-cluster=0`

nocblue has no explicit zram, inotify, `vm.max_map_count`, or TuneD memory
profile layer.

Judgment: `vm.max_map_count`, zram sizing, and inotify limits are low-risk
imports. The TuneD memory sysctls should be imported only as a profile, not
global hard-coded sysctls, because they express a runtime performance policy.

### CPU scheduler and TuneD integration

Bazzite installs `scx-scheds` and `scx-tools`, disables `scx_loader.service` by
default, and maps power-profiles-daemon choices into Bazzite TuneD profiles:

- `balanced -> balanced-bazzite`
- `performance -> throughput-performance-bazzite`
- `balanced-battery -> balanced-battery-bazzite`
- added `power-saver -> powersave-battery-bazzite`

Its TuneD scripts switch sched-ext mode only if `scx_loader.service` is enabled:

- balanced: `scxctl switch -m auto`
- performance: `scxctl switch -m gaming`
- powersave: `scxctl switch -m powersave`

nocblue installs `scx-scheds` and `scx-tools` optionally, but does not wire them
into TuneD/power profiles.

Judgment: good model. Keep sched-ext opt-in, but add TuneD profile integration
if nocblue wants a coherent performance switch instead of loose packages.

### Storage I/O scheduler

Bazzite udev rules set:

- SSD SATA: `kyber`
- NVMe: `kyber`
- microSD: `bfq`
- HDD: `bfq`

nocblue has no storage scheduler rules.

Judgment: candidate import, but verify on the actual NVMe/SATA devices. This is
performance-biased and should be easy to revert.

### Network performance

Bazzite sets:

- `net.ipv4.tcp_congestion_control=bbr`
- `net.ipv4.tcp_mtu_probing=1`
- IPv6 temporary addresses, same as nocblue

nocblue has broader network hardening but not BBR/MTU probing.

Judgment: BBR and MTU probing are good candidates. They do not conflict with
nocblue's existing redirect/source-route hardening.

### Debuggability and reliability toggles

Bazzite leaves most hardening sysctls unset and instead exposes user-facing
toggles for things like SysRq, watchdogs, ramoops, virtualization kargs, and
hardware-specific fixes. It also enables greenboot health checks and uses `uupd`
instead of `rpm-ostreed-automatic.timer`.

nocblue masks SSH and geoclue, disables countme, suppresses coredumps, enables
firewalld, and uses `bootc-fetch-apply-updates.timer` plus
`flatpak-system-update.timer`.

Judgment: nocblue is stricter by default. If this remains a personal image,
strict defaults plus explicit helpers are preferable to enabling broad debug
surfaces by default.

## Recommended nocblue change batches

### Batch 1: low-risk Bazzite parity

Add a dedicated `60-nocblue-performance.conf` instead of mixing performance
knobs into `55-nocblue-hardening.conf`:

- `vm.max_map_count=2147483642`
- `fs.inotify.max_user_instances=8192`
- `fs.inotify.max_user_watches=524288`
- `net.ipv4.tcp_congestion_control=bbr`
- `net.ipv4.tcp_mtu_probing=1`

Add tests for these values in `nocblue-tests`.

### Batch 2: zram and storage rules

Add Bazzite's zram generator policy:

- `compression-algorithm=zstd`
- `zram-size=min(ram / 2, 16384)`

Add I/O scheduler rules only after checking the target machine's actual block
devices and default schedulers. For the current strong desktop hardware, NVMe
`kyber` is the relevant Bazzite comparison point.

### Batch 3: TuneD profile layer

If nocblue wants real performance modes, add TuneD profiles derived from
Bazzite's desktop profiles and map PPD modes to them. Keep `scx_loader.service`
disabled by default and only switch sched-ext modes when the user opted into
that service.

### Batch 4: major gaming stack decision

Do not combine this with sysctl work. Decide separately whether nocblue should
move toward Bazzite's kernel/Mesa/Xwayland/native Steam model. This is the
largest performance delta, but also the largest trust and maintenance delta.

## Initial conclusion

nocblue is not under-hardened compared with Bazzite at the sysctl level. It is
more hardened by default. The real gap is performance and gaming integration:
Bazzite has explicit memory, networking, zram, I/O scheduler, TuneD, kernel,
Mesa, and native gaming-stack choices that nocblue has not fully adopted.

The sensible path is to import low-risk Bazzite parity first, then benchmark or
observe the runtime effect before touching kernel/Mesa or secureblue-style
hardening.
