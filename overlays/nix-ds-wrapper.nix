# Overlay must be a two-arg lambda: final: prev:
final: prev: {
  # Provide a "fake" nix package that only wraps system-level Determinate Nix.
  # The derivation includes common legacy subcommands to satisfy HM activation.
  # It does NOT vendor upstream nix into the store; it just shells out.
  nix-ds = prev.stdenvNoCC.mkDerivation {
    pname = "nix";
    # Any version > 2.2 to satisfy Home Manager's isNixAtLeast check.
    version = "99.0";

    dontUnpack = true;

    installPhase = ''
            set -euo pipefail
            mkdir -p "$out/bin"

            # Provide wrappers for common nix subcommands HM and the ecosystem may call.
            for cmd in nix nix-channel nix-copy-closure nix-env nix-instantiate nix-shell nix-build nix-collect-garbage nix-daemon nix-hash nix-prefetch-url nix-store; do
              cat > "$out/bin/$cmd" <<'SH'
      #!/bin/sh
      exec /nix/var/nix/profiles/default/bin/$(basename "$0") "$@"
      SH
              chmod +x "$out/bin/$cmd"
            done
    '';

    meta = with prev.lib; {
      description = "Wrapper that defers to Determinate Nix at /nix/var/nix/profiles/default/bin/*";
      platforms = platforms.unix;
      # Lower number = higher priority.
      priority = 10;
    };
  };
}
