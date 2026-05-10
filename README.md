# nocblue

`nocblue` is a **beyond opinionated** Fedora Silverblue bootc image for personal use, powered by [Universal Blue](https://github.com/ublue-os). It has both gaming and development packages, there is also the version that uses  [secureblue](https://github.com/secureblue/secureblue) base. It ships with [niri](https://github.com/niri-wm/niri), [Noctalia](https://github.com/noctalia-dev/noctalia-shell), an SDDM login screen, 6 natively installed browsers with curated extension policies/disabled telemetry where supported, ~40 flatpak packages, native Ghostty, OpenRazer and Proton VPN and such.

It also includes various patches for some apps. Steam has GTK theme; Nautilus has an expanded context menu with options to set folder icon, create a new file directly (probably hard to believe if you didn't use Gnome before), and copy file location; Loupe and Showtime reuse the window for new media instead of launching another window.

For installation, you need to be on Fedora Silverblue/Universal Blue base (Bazzite/Aurora/Bluefin...) and run:

```bash
sudo bootc switch ghcr.io/screwys/nocblue:latest
sudo systemctl reboot
```

For secureblue base:
```bash
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/screwys/nocblue-hardened:latest
sudo systemctl reboot
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/screwys/nocblue-hardened:latest
sudo systemctl reboot
```
If the signed rebase fails, set image trust and retry the signed rebase:
```bash
njust image trust ghcr.io/screwys
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/screwys/nocblue-hardened:latest
sudo systemctl reboot
```
For testing in Gnome Boxes, you need to set OS as Silverblue. After machine is set up, you need to enable 3D Accelaration & restart it.

## nocblue commands

```bash
njust status
njust update
njust auto-update-status
njust rollback
njust tests
njust flatpaks
njust flatpak-icon-fixes
njust flatpak-overrides
njust flatpak-overrides-user
njust flatpaks-repair
njust brew
njust android-sdk 36 36.0.0
njust secureboot-check
njust fde-list
njust fde-status /dev/nvme0n1p3
njust fde-tpm2 /dev/nvme0n1p3 yes 7
njust fde-recovery-key /dev/nvme0n1p3
njust container-userns status
njust unconfined-userns status
njust image trust ghcr.io/screwys
njust image trust-user ghcr.io/screwys
njust image trust-show
njust image trust-show-user
njust image check-secureblue
```

`njust image trust ...` changes the system container policy through `run0` or `sudo`. `njust image trust-user ...` writes the current user's rootless Podman policy.
`njust image check-secureblue` compares the published `nocblue-hardened` image against the current secureblue base image.
