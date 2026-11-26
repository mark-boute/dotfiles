# dotfiles (dendritic)

NixOS configuration for `legion` (Mark) and `marijn-laptop` (Marijn), built with
[flake-parts](https://flake.parts) and [import-tree](https://github.com/vic/import-tree).

## How it works

Every `.nix` file under `modules/` is loaded automatically; there are no import lists to
maintain. Each file defines one or more **aspects**: a named piece of configuration such as
`steam`, `gnome` or `zsh`.

```nix
{ config, ... }:
let
  inherit (config.flake.modules) homeManager;
in
{
  flake.modules.nixos.latex = {
    home-manager.sharedModules = [ homeManager.latex ];  # pulls in the home half
  };

  flake.modules.homeManager.latex = { pkgs, ... }: {
    home.packages = [ pkgs.texliveSmall ];
  };
}
```

- `flake.modules.nixos.<name>` is the system side; `flake.modules.homeManager.<name>` is the
  home-manager side. Importing the NixOS aspect brings its home side along.
- A **host** is just a list of aspects plus its own settings
  (`modules/hosts/<host>/default.nix`).
- Files and folders starting with `_` are not loaded (e.g. `_km-print/`, a plain package).

## Layout

```
modules/
├── flake/         flake-parts setup (systems, formatter)
├── system/        base, nix, user, sops, audio, networking, flatpak, peripherals/
├── desktop/       gnome, hyprland, resonate, theme
├── applications/  gaming/, editors/, shell/, ai/, obsidian, spotify, development
└── hosts/
    ├── legion/          hardware, gpu, kernel, hypr/, users/mark.nix
    └── marijn-laptop/   hardware, users/scarletto.nix
```

## Per-host settings (`my.*`)

Aspects read host-specific facts from these options instead of hardcoding them:

| Option | Meaning |
|---|---|
| `my.user.name` / `fullName` / `email` | the host's main user; the account is created from this |
| `my.flakeDir` | where this flake is checked out (default `~/dotfiles/dendritic`) |
| `my.gnome.*` | wallpaper, light/dark, shell blur |

Hover over them in VS Code (nixd) for descriptions.

## Adding a host

1. Create `modules/hosts/<host>/default.nix` with
   `flake.nixosConfigurations.<host>` and a `flake.modules.nixos.<host>` that imports the
   aspects you want (copy `marijn-laptop` as a starting point).
2. Turn the generated `hardware-configuration.nix` into `hardware.nix`, wrapped in
   `flake.modules.nixos.<host>-hardware = { ... };`.
3. Add `users/<user>.nix` that sets `my.user` and the user's own packages.
4. Set `system.stateVersion` to the NixOS version the machine was installed with, and never
   change it afterwards.
5. **Change the password after the first login.** New accounts start with
   `initialPassword = "hello"`, which is public in this repo. Run `passwd` right away.

## Commands

| Command | What it does |
|---|---|
| `nh os switch ~/dotfiles/dendritic` | build and switch (Mark: `switch` alias) |
| `nix fmt` | format all `.nix` files with nixfmt |
| `nix flake check` | evaluate every host without building the systems (CI runs this) |

## Warnings

Some settings are waiting on a decision or a re-test. Those add an entry to `warnings`, so
every rebuild prints a reminder. Remove the warning together with the decision.
