# nocblue

`nocblue` is a maximal (yes, truly) Fedora Silverblue bootc image for personal use, powered by [Universal Blue](https://github.com/ublue-os). It has both gaming and development packages as well as some hardening defaults which are borrowed from [secureblue](https://github.com/secureblue/secureblue) with a partially active hardened malloc (I don't guarantee it is as effective as secureblue, it probably is not). It ships with [niri](https://github.com/niri-wm/niri), [Noctalia](https://github.com/noctalia-dev/noctalia-shell), 4 natively installed browsers, 30+ flatpak packages, Ghostty, OpenRazer and Proton VPN.

For installation, use a Fedora Silverblue base and run:

```bash
sudo bootc switch ghcr.io/screwys/nocblue:latest
sudo systemctl reboot
```
