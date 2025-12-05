{ config, lib, ... }:

let
  cfg = config.modules.hyprland.shared.keybinds; 
  inherit (lib) mkEnableOption mkIf;
in
{
  imports = [
    ./applications.nix
    ./hardware-control.nix
    ./window-management.nix
    ./workspaces.nix
  ];

  options.modules.hyprland.shared.keybinds = { 
    enable-all = mkEnableOption "Enable all Hyprland shared keybinds";
  };

  config = mkIf cfg.enable-all {
    modules.hyprland.shared.keybinds = {
      applications.enable = true;
      hardware-control.enable = true;
      window-management.enable = true;
      workspaces.enable = true;
    };
  };
}