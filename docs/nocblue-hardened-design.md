# nocblue-hardened draft

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
- Development, gaming, OCR, input, local-service, and browser packages that are
  not already supplied by secureblue.

## Intentionally omitted in the draft recipe

- `hardened_malloc`, `no_rlimit_as`, `trivalent`, `trivalent-selinux`, and
  known secureblue-supplied packages.
- `configure-hardened-malloc.sh` and `nocblue-hardened-malloc-flatpaks.service`;
  secureblue owns the global allocator policy.
- `configure-ipsec-selinux.sh`; secureblue now has its own network/module
  hardening, so nocblue's extra SELinux denial needs a separate decision.
- `nocblue-flatpak-overrides.service`; secureblue's Flatpak hardening must be
  treated as the baseline before applying nocblue ergonomics.
- `bootc-fetch-apply-updates.timer` and `flatpak-system-update.timer`;
  secureblue has its own update units and verification flow.
- `finalize.sh` and `validate-image.sh`; both currently encode standard
  nocblue assumptions and need a hardened-specific pass before use.

## Known follow-up work

- Split `files/system` into shared desktop/default files and standard-only
  hardening files, or add a hardened-specific cleanup script. Copying the whole
  tree is useful for a draft but still brings inert hardening helpers into the
  image.
- Add a `nocblue-tests --profile hardened` path or separate hardened test
  script. The current test contract assumes the standard image.
- Decide whether the hardened image should include the installer/ISO packages
  or only support `bootc switch`.
- Decide whether Firefox belongs in the hardened variant. Secureblue removes it
  and installs Trivalent as the primary browser.
- Validate LibreWolf packaging after the current upstream signature issue is
  resolved. The draft pins `librewolf-150.0.1-1.x86_64` to match the current
  repo fix.
- Build manually before wiring the recipe into GitHub Actions or README install
  instructions.
