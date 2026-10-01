# nocblue

<img width="2556" height="1439" alt="b" src="https://github.com/user-attachments/assets/cbb958b7-6ceb-4148-a74e-dde349ff8973" />

`nocblue` is a **beyond opinionated** Fedora Silverblue bootc image for personal use, powered by [Universal Blue](https://github.com/ublue-os) and based on [secureblue](https://github.com/secureblue/secureblue). It has both gaming and development packages. It ships with [niri](https://github.com/niri-wm/niri), [Noctalia v5](https://github.com/noctalia-dev/noctalia), nix, the official Noctalia Greeter on greetd, 6 natively installed browsers with preinstalled extensions/disabled telemetry, ~50 flatpak packages, native Ghostty, OpenRazer and Proton VPN.

User namescapes are enabled per browser, allowing them to use their own sandboxing, while keeping broad user namespaces disabled, respecting secureblue default. 

Native single-user Nix is available through `/usr/bin/nix`. The desktop user owns the persistent store at `/var/home/nix`, mounted at `/nix`. Nix runs as that user and builds use its namespace sandbox. A weekly user timer collects unused store paths and keeps profile generations and running packages. Bash and fish append `~/.nix-profile/bin` after existing system, user, and Homebrew paths, so profile tools can be called directly without replacing host commands.

This personal image creates a new store for UID 1000 and GID 1000. For another owner, override `/usr/lib/tmpfiles.d/nocblue-nix.conf` with `/etc/tmpfiles.d/nocblue-nix.conf` before the first boot. Existing store ownership remains unchanged.

On the first login after moving from nix-portable, nocblue saves the old profile manifest and symlinks under `~/.local/state/nocblue/nix-portable-migration`, restores active package selections, and installs missing image tools. It removes only recorded nocblue command shims with the managed marker. The old `~/.nix-portable` store remains available for recovery. A package without a source reference must still be available at its store path; otherwise setup reports a migration failure and retains the saved selection.

Nautilus has an expanded context menu with options to set folder icon, create a new file directly (probably hard to believe if you didn't useGNOME before), and copy file location; Loupe and Showtime reuse the window for new media instead of launching another window, and they also only mount the current folder read-only for extra hardening, which even disables basics like cropping.

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

For testing in a VM, you need to enable 3D Accelaration.
