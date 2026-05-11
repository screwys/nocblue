# nocblue-hardened manual test recipe

`nocblue-hardened` should be a separate image, not a rebuild of the standard
`nocblue` recipe with only `base-image` changed.

The secureblue base already brings a full hardening stack. The current upstream
source checked for this pass was secureblue commit `67386b5`, where
`recipes/general/recipe-silverblue-main.yml` builds `silverblue-main-hardened`
from Fedora Silverblue with common, Silverblue, desktop, proprietary, SELinux,
and final modules.

## Keep from secureblue

- Global hardened malloc setup through `/etc/ld.so.preload`, PAM environment,
  profile environment, and systemd manager config.
- Trivalent and `trivalent-selinux`, installed through secureblue's verified
  Trivalent flow.
- Secureblue SELinux policy modules, including user namespace policy.
- Secureblue sysctl hardening, modprobe policy, service presets, and disabled
  desktop services.
- Secureblue Flatpak setup and update behavior. The hardened image layers
  nocblue's user Flatpak setup after secureblue's baseline instead of baking
  system Flatpaks into the image.
- Secureblue's native Bazaar package and first-boot cleanup service. Bazaar
  stays native so it follows secureblue's store policy, while the cleanup
  service removes system Flatpaks and default Fedora/Flathub remotes left by
  the installer or accidental app-store transactions.

## Layer from nocblue

- niri, Noctalia, SDDM, Ghostty, desktop defaults, and user-default migration.
- nocblue browser policy files, with Trivalent policy layered onto secureblue's
  native Trivalent install.
- nocblue app patches for Loupe, Showtime, Nautilus helpers, Noctalia plugins,
  pywalfox, Proton VPN, and SDDM theme.
- Standard nocblue development, gaming, OCR, input, local-service, and browser
  package choices, even when secureblue already happens to include one of those
  tools. Hardened package parity should be deliberate, not accidental.
- Firefox, LibreWolf, Brave Origin, Helium, and Mullvad Browser stay in the
  hardened image as part of nocblue's normal browser set; Trivalent remains
  available from secureblue as the hardened browser. These extra browsers
  launch with standard malloc because the secureblue full-system hardened malloc
  preload makes them abort or crash during startup.
- Brave Origin and Helium launch in nocblue-specific SELinux domains that keep
  secureblue's global unconfined-domain user namespace toggle disabled while
  allowing only those browser domains to create user namespaces for Chromium
  sandbox startup.
- Hardened-specific repo handling: the manual recipe does not use BlueBuild's
  `nonfree: rpmfusion` helper because secureblue removes the
  `fedora-cisco-openh264` repo and uses its own multimedia/repo baseline.

## Intentionally omitted in the manual recipe

- `hardened_malloc`, `trivalent`, and `trivalent-selinux`; secureblue owns
  those hardening and browser-policy packages.
- `no_rlimit_as` is layered by nocblue-hardened because secureblue's global
  preload configuration references `libno_rlimit_as.so`, and the ISO live
  environment must have that shared object available before login.
- `configure-hardened-malloc.sh` and `nocblue-hardened-malloc-flatpaks.service`;
  secureblue owns the global allocator policy.
- `configure-ipsec-selinux.sh`; secureblue now has its own network/module
  hardening, so nocblue's extra SELinux denial needs a separate decision.
- `nocblue-hardened-malloc-flatpaks.service`, `nocblue-flatpak-overrides.service`,
  and `flatpak-system-update.timer`; secureblue owns the global user Flatpak
  hardened-malloc baseline and user update flow. Hardened installs nocblue
  Flatpaks through `nocblue-flatpak-setup.timer`, which reapplies app-specific
  user overrides after secureblue's setup.
- `bootc-fetch-apply-updates.timer`; secureblue has its own update units and
  verification flow.
- `finalize.sh` and `validate-image.sh`; both currently encode standard
  nocblue assumptions and need a hardened-specific pass before use.
- OpenRazer post-install commands. Both recipes use the build-time akmods
  module for the kernel modules, then install `openrazer-daemon`,
  `python3-openrazer`, and `polychromatic` afterward. That lets DNF satisfy the
  daemon's kernel-module dependency from ublue's `openrazer-kmod-common`
  provider instead of pulling the OBS DKMS package.

## Known follow-up work

- Split `files/system` into shared desktop/default files and standard-only
  hardening files, or add a hardened-specific cleanup script. Copying the whole
  tree is useful for manual build validation but still brings inert hardening
  helpers into the image.
- Add a `nocblue-tests --profile hardened` path or separate hardened test
  script. The current test contract assumes the standard image.
- Decide whether the hardened image should include the installer/ISO packages
  or only support `bootc switch`.
- Keep the LibreWolf pin current. The repo has had recent package-signature
  churn, so both standard and hardened recipes should move together after a
  download/signature check.
- Revisit any missing packages one by one if removing the RPMFusion helper
  exposes a concrete package-source gap in the hardened workflow.
- Use the `hardened` workflow with `publish=false` for build validation, then
  rerun it with `publish=true` only when we are ready to boot-test the published
  `ghcr.io/screwys/nocblue-hardened:latest` image.
