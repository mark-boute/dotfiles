# Hyprland

Be sure to read the [Hyprland Wiki](https://wiki.hypr.land/Nix/Hyprland-on-Home-Manager/)!

## Requirements

1. Set `programs.hyprland.enable = true;` in your configuration (system level)
2. Add `pkgs.kitty` to your `environment.systemPackages`, unless you know what you are doing.
3. [Optional] `environment.sessionVariables.NIXOS_OZONE_WL = "1";` to hint Electron applications to use Wayland

## Setup

This folder contains multiple setups for Hyprland to try out, each has its own folder, with some shared modules.
You may enable **one** of these at a time in your home.nix file using `modules.hyprland.configuration = "<folder_name_here>"` and `modules.hyprland.enable = true`
