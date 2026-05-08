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
- Secureblue Flatpak setup and update behavior until we decide which nocblue
  overrides are compatible.

## Layer from nocblue

- niri, Noctalia, SDDM, Ghostty, desktop defaults, and user-default migration.
- nocblue browser policy files, with Trivalent policy layered onto secureblue's
  native Trivalent install.
- nocblue app patches for Loupe, Showtime, Nautilus helpers, Noctalia plugins,
  pywalfox, Proton VPN, and SDDM theme.
- Standard nocblue development, gaming, OCR, input, local-service, and browser
  package choices, even when secureblue already happens to include one of those
  tools. Hardened package parity should be deliberate, not accidental.
- Firefox stays in the hardened image as part of nocblue's normal browser set;
  Trivalent remains available from secureblue as the hardened browser.
- Hardened-specific repo handling: the manual recipe does not use BlueBuild's
  `nonfree: rpmfusion` helper because secureblue removes the
  `fedora-cisco-openh264` repo and uses its own multimedia/repo baseline.

## Intentionally omitted in the manual recipe

- `hardened_malloc`, `no_rlimit_as`, `trivalent`, and `trivalent-selinux`;
  secureblue owns those hardening and browser-policy packages.
- `configure-hardened-malloc.sh` and `nocblue-hardened-malloc-flatpaks.service`;
  secureblue owns the global allocator policy.
- `configure-ipsec-selinux.sh`; secureblue now has its own network/module
  hardening, so nocblue's extra SELinux denial needs a separate decision.
- `nocblue-hardened-malloc-flatpaks.service`; secureblue owns the global
  Flatpak hardened-malloc baseline. The lighter nocblue Flatpak override
  service stays enabled so bundled apps like Steam get compatibility overrides.
- `bootc-fetch-apply-updates.timer` and `flatpak-system-update.timer`;
  secureblue has its own update units and verification flow.
- `finalize.sh` and `validate-image.sh`; both currently encode standard
  nocblue assumptions and need a hardened-specific pass before use.
- OpenRazer post-install commands; the hardened recipe uses the build-time
  akmods module instead. Direct `rpm-ostree install openrazer-meta` during image
  composition runs the DKMS RPM scriptlet against the build host kernel. The
  ublue akmods repo file is present but disabled by default so the akmods module
  can enable it only while resolving the OpenRazer kmod-common package.

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
