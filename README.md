# nocblue

`nocblue` is a **beyond opinionated** Fedora Silverblue bootc image for personal use, powered by [Universal Blue](https://github.com/ublue-os) and based on [secureblue](https://github.com/secureblue/secureblue). It has both gaming and development packages. It ships with [niri](https://github.com/niri-wm/niri), [Noctalia](https://github.com/noctalia-dev/noctalia-shell), nix, a noctalia based SDDM login screen, 6 natively installed browsers with preinstalled extensions/disabled telemetry, ~40 flatpak packages, native Ghostty, OpenRazer and Proton VPN.

User namescapes are enabled per browser, allowing them to use their own sandboxing, while keeping broad user namespaces disabled, respecting secureblue default. Nix lives in `/usr/bin/` so all plain nix commands work from terminal except profile which is deliberately disabled (This is achieved by custom SElinux policies). Store is at ``~/.nix-portable/nix/store/`, and it is cleaned weekly with a systemd timer.


Steam has GTK theme; Nautilus has an expanded context menu with options to set folder icon, create a new file directly (probably hard to believe if you didn't useGNOME before), and copy file location; Loupe and Showtime reuse the window for new media instead of launching another window, and they also only mount the current folder read-only for extra hardening, which even disables basics like cropping.

For installation, you need to be on Fedora Silverblue/Universal Blue base (Bazzite/Aurora/Bluefin...) and run:

```bash
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/screwys/nocblue:latest
sudo systemctl reboot
```

and then:

```bash
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/screwys/nocblue:latest
sudo systemctl reboot
```

For testing in GNOME Boxes, you need to set OS as Silverblue. After machine is set up, you need to enable 3D Accelaration & restart it.

## nocblue commands

`njust image trust ...` changes the system container policy through `run0` or `sudo`. `njust image trust-user ...` writes the current user's rootless Podman policy.

`njust image check-secureblue` compares the published `nocblue` image against the current secureblue base image.

`njust openrazer-plugdev enable` opts the current user into the `plugdev` group for OpenRazer; log out and back in afterwards.
