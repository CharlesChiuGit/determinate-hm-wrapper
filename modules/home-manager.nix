# Home Manager module for non-NixOS/non-darwin hosts that:
# 1) Sets nix.package to the wrapper (pkgs.nix-ds) to satisfy HM assertions,
# 2) Keeps HM-side nix.settings to upstream-compatible keys only,
# 3) Leaves Determinate-specific keys (lazy-trees, eval-cores, etc.) to /etc/nix/nix.custom.conf,
# 4) Ensures PATH finds system-level Determinate Nix first,
# 5) Performs a basic activation-time health check.

{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.determinate.hm;
in
{
  options.determinate.hm.enable = lib.mkEnableOption "Determinate Nix wrapper for Home Manager (non-NixOS/non-darwin)";

  config = lib.mkIf (cfg.enable or true) {
    # Use the wrapper as nix.package so HM can generate nix.conf without pulling upstream nix.
    nix.package = pkgs.nix-ds;

    # Ensure interactive shells resolve Determinate Nix first.
    home.sessionPath = lib.mkBefore [ "/nix/var/nix/profiles/default/bin" ];

    # Activation-time health check for Determinate Nix presence.
    home.activation.determinateNixCheck = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -x /nix/var/nix/profiles/default/bin/nix ]; then
        echo "Determinate Nix not found at /nix/var/nix/profiles/default/bin/nix"
        echo "Install it from: https://github.com/DeterminateSystems/determinate/blob/main/README.md#installing-using-the-determinate-nix-installer"
        exit 1
      fi

      # Optional warnings if legacy subcommands are missing in minimal installs.
      for cmd in nix nix-channel nix-copy-closure nix-env nix-instantiate nix-shell nix-build nix-collect-garbage nix-daemon nix-hash nix-prefetch-url nix-store; do
        if [ ! -x "/nix/var/nix/profiles/default/bin/$cmd" ]; then
          echo "warning: Determinate Nix missing $cmd at /nix/var/nix/profiles/default/bin/$cmd"
        fi
      done
    '';
  };
}
