#!/usr/bin/env zsh
# Tailscale CLI shim — Mac App Store variant only.
# Added 2026-07-05: this Mac has the App Store variant of Tailscale
# (confirmed via /Applications/Tailscale.app/Contents/_MASReceipt), which
# has no /usr/local/bin/tailscale launcher option — the CLI only exists
# inside the app bundle. Guarded so it never shadows a real `tailscale`
# binary if this machine ever switches to the Standalone variant, or if
# Homebrew's tailscale formula is ever (deliberately) installed instead --
# see tailscale.com/docs/concepts/macos-variants: the App Store variant,
# Standalone variant, and Homebrew's open-source tailscaled formula are
# three incompatible things and must never coexist as the active CLI.
if ! command -v tailscale &>/dev/null \
   && [[ -x "/Applications/Tailscale.app/Contents/MacOS/Tailscale" ]]; then
  alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
fi
# Note: `tailscale ssh` is unavailable on this sandboxed MAS variant.
# Use the regular ssh client instead (see travel/remote-access setup).
