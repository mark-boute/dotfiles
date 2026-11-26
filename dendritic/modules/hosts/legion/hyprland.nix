{ config, ... }:
let
  inherit (config.flake.modules) homeManager;
in
{
  # legion's monitors, GPU env and autostart, loaded by hyprland.lua's try_require
  flake.modules.nixos.legion-hyprland = { config, pkgs, ... }: {
    home-manager.sharedModules = [ homeManager.legion-hyprland ];

    # "Hyprland (dGPU)" GDM entry: HYPR_DGPU=1 makes hypr/nvidia.lua render on the dGPU
    services.displayManager.sessionPackages = [
      (
        (pkgs.writeTextDir "share/wayland-sessions/hyprland-dgpu.desktop" ''
          [Desktop Entry]
          Name=Hyprland (dGPU)
          Comment=Hyprland and all apps rendered on the NVIDIA GPU
          Exec=${pkgs.writeShellScript "hyprland-dgpu" ''
            export HYPR_DGPU=1
            exec ${config.programs.hyprland.package}/bin/start-hyprland "$@"
          ''}
          DesktopNames=Hyprland
          Type=Application
        '').overrideAttrs
          { passthru.providedSessions = [ "hyprland-dgpu" ]; }
      )
    ];
  };

  flake.modules.homeManager.legion-hyprland = { config, osConfig, ... }: {
    xdg.configFile = builtins.listToAttrs (
      map (name: {
        name = "hypr/${name}";
        value.source = config.lib.file.mkOutOfStoreSymlink "${osConfig.my.live ./hypr}/${name}";
      }) (builtins.attrNames (builtins.readDir ./hypr))
    );
  };
}
