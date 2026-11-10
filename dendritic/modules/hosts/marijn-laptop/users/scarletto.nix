{ inputs, ... }:
{
  flake.modules.nixos.scarletto = { config, pkgs, lib, ... }:
  let
    flake = config.my.flakeDir;
    host = "${flake}/modules/hosts/marijn-laptop";
  in
  {
    my.user = {
      name = "scarletto";
      fullName = "Marijn Meuleman";
      email = "marijn2312@gmail.com";
    };

    my.gnome.preferLight = true;

    users.users.scarletto = {
      initialPassword = "hello";
      extraGroups = [ "dialout" "docker" ];
      shell = pkgs.bash;
    };

    programs.bash = {
      enable = true;
      shellAliases = {
        n-rebuild = "sudo nixos-rebuild switch --flake ${flake}";
        n-update = "sudo nix flake update --flake ${flake} && sudo nixos-rebuild switch --flake ${flake}";
        n-config = "nano ${host}/default.nix";
        n-home = "nano ${host}/users/scarletto.nix";
        n-env = "nix develop";
        n-flake-generate = "cp ${host}/blank_flake ./flake.nix && nano ./flake.nix";
        n-flake = "nano ./flake.nix";
        n-direnv-generate = "touch .envrc && echo \"use flake\" > .envrc && nano ./.envrc";
        n-direnv-allow = "direnv allow";
        n-direnv = "nano ./.envrc";
      };
    };

    home-manager.users.scarletto = {
      home.stateVersion = "24.05"; # Please read the comment before changing.

      home.packages = with pkgs; [
        vscode
        typst

        gh
        glab

        discord
        signal-desktop
        slack

        gimp
        ffmpeg

        inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default

        eduvpn-client
        openvpn

        openscad
        orca-slicer

        hplip
        usbutils

        (lib.warnIfNot (lib.hasInfix "-firefox-esr-140-bin-unwrapped-" zotero.buildPhase)
          "EXPIRING OVERRIDE: zotero no longer bundles firefox-esr-140-bin-unwrapped. Remove it from hosts/marijn-laptop/default.nix!"
          zotero)
      ];

      programs.git = {
        enable = true;
        settings = {
          user.name = "Marijn Meuleman";
          user.email = "marijn2312@gmail.com";
          aliases = {
            s = "status";
            c = "commit";
            b = "switch"; # yep, this is on purpose
            d = "diff";
            l = "log";
            p = "push";
            f = "fetch";
            a = "add";
          };
          push = { autoSetupRemote = true; };
        };
      };

      programs.diff-so-fancy.enable = true;

      programs.obsidian = {
        enable = true;
        vaultEnvs.enable = true;
        vaultEnvs.hideNormalApp = true;
      };
    };
  };
}
