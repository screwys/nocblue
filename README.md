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
sudo bootc switch ghcr.io/screwys/nocblue-hardened:latest
sudo systemctl reboot
```
For testing in Gnome Boxes, you need to set OS as Silverblue. After machine is set up, you need to enable 3D Accelaration & restart it.
