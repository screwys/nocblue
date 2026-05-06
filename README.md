# nocblue

`nocblue` is a **beyond opinionated** Fedora Silverblue bootc image for personal use, powered by [Universal Blue](https://github.com/ublue-os). It has both gaming and development packages, also some minimal hardening defaults borrowed from [secureblue](https://github.com/secureblue/secureblue) with a partially active hardened malloc (I don't guarantee it is as effective as secureblue, it probably is not). It ships with [niri](https://github.com/niri-wm/niri), [Noctalia](https://github.com/noctalia-dev/noctalia-shell), 4 natively installed browsers with pre-installed extensions/disabled telemetry and such, ~40 flatpak packages, native Ghostty, OpenRazer and Proton VPN and such.

It also includes various patches for some apps. Steam has GTK theme; Nautilus has an expanded context menu with options to set folder icon, create a new file directly (probably hard to believe if you didn't use Gnome before), and copy file location; Loupe and Showtime to reuse the window for new files instead of launching another window.

For installation, you can download the latest iso artifact from actions or use a Fedora Silverblue base (or Bazzite/Aurora/Bluefin etc) and run:

```bash
sudo bootc switch ghcr.io/screwys/nocblue:latest
sudo systemctl reboot
```
For testing in Gnome Boxes, you need to set OS as Silverblue. After machine is set up, you need to enable 3D Accelaration & restart it. 
