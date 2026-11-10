{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  # Per-host facts every aspect reads: the host's main user and where this flake
  # is checked out. NixOS modules use config.my, home-manager modules osConfig.my.
  flake.modules.nixos.user = { config, lib, ... }:
  let
    cfg = config.my;
  in
  {
    imports = [ nixos.home-manager ];

    options.my = {
      user = {
        name = lib.mkOption { type = lib.types.str; };
        fullName = lib.mkOption { type = lib.types.str; };
        email = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
      };
      # out-of-store symlinks point here, so edits apply without a rebuild
      flakeDir = lib.mkOption {
        type = lib.types.str;
        default = "/home/${cfg.user.name}/dotfiles/dendritic";
      };
      # `live ./foo` turns a path in this flake into its checkout path under flakeDir
      live = lib.mkOption {
        type = lib.types.functionTo lib.types.str;
        readOnly = true;
        default = path: cfg.flakeDir + lib.removePrefix (toString inputs.self) (toString path);
      };
    };

    config = {
      users.users.${cfg.user.name} = {
        isNormalUser = true;
        description = cfg.user.fullName;
        extraGroups = [ "networkmanager" "wheel" ];
      };

      home-manager.users.${cfg.user.name} = {
        home.username = cfg.user.name;
        home.homeDirectory = "/home/${cfg.user.name}";
        programs.home-manager.enable = true;
      };
    };
  };
}
