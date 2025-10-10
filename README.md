# determinate-hm-wrapper

> [!WARNING]
> This is a stopgap approach for enabling Determinate Nix features (e.g., `lazy-trees`, `eval-cores`) with standalone Home Manager on non-NixOS/non-nix-darwin systems. It is not fully tested across distributions and does not guarantee proper utilization of those features.

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

`flake.nix`:

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
        determinate-hm-wrapper.overlays.default # recommanded
      ];
    };
  in {
    homeConfigurations."username@host" = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        determinate-hm-wrapper.homeManagerModules.default # optional, it might conflicted with other modules
        # ...your existing HM modules...
      ];
    };
  };
}
```

`home.nix`:

```nix
{
  config,
  pkgs,
  lib,
  ...
}:
{
  nix = {
    package = pkgs.nix-ds; # <-- NOTE: replace `pkgs.nix` with `pkgs.nix-ds`
    checkConfig = true;
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      use-xdg-base-directories = true;
      cores = 0;
      max-jobs = 10;
      auto-optimise-store = true;
      warn-dirty = false;
      http-connections = 50;
      trusted-users = "username";
    };
    gc = {
      automatic = true;
      options = "--delete-older-than 7d --max-freed $((1 * 1024**3))";
    };
  };
  ...
}

```

`/etc/nix/nix.custom.conf`:

```conf
# Written by https://github.com/DeterminateSystems/nix-installer.
# The contents below are based on options specified at installation time.

trusted-users = your_name
lazy-trees = true
eval-cores = 0
```

Then restart nix daemon:

on macOS:

```sh
sudo launchctl unload /Library/LaunchDaemons/systems.determinate.nix-daemon.plist
sudo launchctl load /Library/LaunchDaemons/systems.determinate.nix-daemon.plist
```

on Ubuntu:

```sh
sudo systemctl restart nix-daemon
```
