{ config, pkgs, lib, inputs, ... }:

let
  cfg = config.modules.hyprland.cappuccino;
  inherit (lib) mkEnableOption mkIf;
in
{
  imports = [
    ./wallpaper.nix
    ./quickshell
  ];

  options.modules.hyprland.cappuccino = { 
    enable = mkEnableOption "Enable Cappucinno Hyprland configuration";
  };

  config = mkIf cfg.enable {
    modules.hyprland.cappuccino.quickshell.enable = true;
  };
}