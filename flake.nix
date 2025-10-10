{
  description = "Determinate Nix wrapper overlay & Home Manager module for non-NixOS/non-darwin";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0.1";
    nix-filter.url = "github:numtide/nix-filter";
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-filter,
      ...
    }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      forEachSupportedSystem =
        f:
        nixpkgs.lib.genAttrs supportedSystems (
          system:
          f {
            inherit system;
            pkgs = import nixpkgs {
              inherit system;
              config = {
                allowUnfree = true;
              };
            };
          }
        );

      src = nix-filter.lib.filter {
        root = ./.;
        include = [
          "flake.nix"
          "flake.lock" # keep lockfile for reproducibility
          "overlays"
          "modules"
        ];
      };
    in
    {
      formatter = forEachSupportedSystem ({ pkgs, ... }: pkgs.nixfmt-rfc-style);

      filter = nix-filter.lib;

      # Expose overlay and HM module from the filtered source
      overlays.default = import "${src}/overlays/nix-ds-wrapper.nix";
      homeManagerModules.default = import "${src}/modules/home-manager.nix";

      # Optional: publish a package for quick build testing
      packages = forEachSupportedSystem (
        { pkgs, ... }:
        {
          inherit ((import "${src}/overlays/nix-ds-wrapper.nix" pkgs pkgs)) nix-ds;
          default = self.packages.${pkgs.stdenv.system}.nix-ds;
        }
      );

      # Optional: expose filtered source for debugging (nix build .#source)
      source = src;
    };
}
