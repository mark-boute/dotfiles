{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  # Per-host facts every aspect reads: the host's main user and where this flake
  # is checked out. NixOS modules use config.my, home-manager modules osConfig.my.
  flake.modules.nixos.user =
    { config, lib, ... }:
    let
      cfg = config.my;
    in
    {
      imports = [ nixos.home-manager ];

      options.my = {
        user = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Login name of the host's main user; the account and its home-manager config are created for it.";
          };
          fullName = lib.mkOption {
            type = lib.types.str;
            description = "Full name, used for the account description and git.";
          };
          email = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Email address, used by git.";
          };
        };
        flakeDir = lib.mkOption {
          type = lib.types.str;
          description = "Where this flake is checked out. Live config links (hypr, resonate, VS Code) and the nh/switch aliases point here.";
          default = "/home/${cfg.user.name}/dotfiles/dendritic";
        };
        live = lib.mkOption {
          type = lib.types.functionTo lib.types.str;
          readOnly = true;
          description = "Helper: `live ./foo` gives the checkout path of ./foo under flakeDir, for links that apply without a rebuild.";
          default = path: cfg.flakeDir + lib.removePrefix (toString inputs.self) (toString path);
        };
      };

      config = {
        users.users.${cfg.user.name} = {
          isNormalUser = true;
          description = cfg.user.fullName;
          extraGroups = [
            "networkmanager"
            "wheel"
          ];
        };

        home-manager.users.${cfg.user.name} = {
          home.username = cfg.user.name;
          home.homeDirectory = "/home/${cfg.user.name}";
          programs.home-manager.enable = true;
        };
      };
    };
}
