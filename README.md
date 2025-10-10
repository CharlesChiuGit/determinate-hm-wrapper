# determinate-hm-wrapper

> warning: This a hot-glue solution to utilize Determinate Nix features, like
> `lazy-trees` and `eval-cores` to standalone hom-manager on
> non-NixOS/non-nix-darwin, this does not fully tested on every Distros and does
> not guarantee Determinate Nix's features are properly utilized.

A minimal overlay + Home Manager (HM) module that makes **non-NixOS / non-nix-darwin** hosts use the **system-level Determinate Nix** binaries during Home Manager evaluation and activation — **without** pulling the original `nix` from `nixpkgs`.

- ✅ Satisfies HM’s `nix.package` assertion (via a small wrapper package)
- ✅ Calls the system Determinate Nix at `/nix/var/nix/profiles/default/bin/*`
- ✅ Provides legacy subcommands (`nix-build`, `nix-env`, etc.) as wrappers to avoid activation errors
- ✅ Keeps Determinate-specific settings (e.g., `lazy-trees`, `eval-cores`) in **system config**, not HM
- ✅ Ships with `nix-filter` to keep the flake source minimal and reproducible

> Target audience: users running **Home Manager standalone** on Linux or macOS, with **Determinate Nix installed via the official installer**, but **not** using NixOS or nix-darwin.

---

## Contents

- `overlays/nix-ds-wrapper.nix` — a tiny derivation exposing `bin/nix` and common legacy subcommands; each shell-outs to `/nix/var/nix/profiles/default/bin/<cmd>`
- `modules/home-manager.nix` — an HM module that:
  - sets `nix.package = pkgs.nix-ds`
  - defines **upstream-compatible** `nix.settings` only (no Determinate-only keys here)
  - ensures PATH finds the system Determinate Nix first
  - performs a basic activation-time health check
- `flake.nix` — exports:
  - `overlays.default`
  - `homeManagerModules.default`
  - `packages.<system>.nix-ds` (optional convenience)
  - `source` (filtered with `nix-filter`)

---

## Prerequisites

- **Determinate Nix** installed system-wide (provides `/nix/var/nix/profiles/default/bin/nix`, etc.).
  - Installer: https://install.determinate.systems/nix
- **Home Manager (standalone)** for your user (no NixOS / nix-darwin required).
- `flakes` and `nix-command` enabled.

> Determinate-specific settings like `lazy-trees` and `eval-cores` should live in **`/etc/nix/nix.custom.conf`** (system-level), not in HM. This repo intentionally keeps HM settings upstream-compatible.

---

## Quick Start

Add this repo as a flake input in your **home-manager config's** flake:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    determinate-hm-wrapper.url = "github:CharlesChiuGit/determinate-hm-wrapper";
  };

  outputs = { self, nixpkgs, home-manager, determinate-hm-wrapper, ... }: let
    system = "x86_64-linux"; # or aarch64-linux / x86_64-darwin / aarch64-darwin
    pkgs = import nixpkgs {
      inherit system;
      overlays = [
        determinate-hm-wrapper.overlays.default
      ];
    };
  in {
    homeConfigurations."user@host" = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        determinate-hm-wrapper.homeManagerModules.default
        # ...your existing HM modules...
      ];
    };
  };
}
```
