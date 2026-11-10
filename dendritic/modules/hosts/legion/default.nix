{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  flake.nixosConfigurations.legion = inputs.nixpkgs.lib.nixosSystem {
    modules = [ nixos.legion ];
  };

  flake.modules.nixos.legion = { pkgs, ... }: {
    imports = with nixos; [
      # system
      base
      nix
      sops
      networking
      audio
      flatpak
      mark

      # desktop
      gnome
      hyprland
      resonate
      assistant
      catppuccin

      # shell & editors
      zsh
      git
      vscode
      latex

      # applications
      development
      spotify
      ollama
      claude-desktop

      # gaming & peripherals
      steam
      mangohud
      gamemode
      steam-controller-pad
      minecraft
      arctis
      openrgb

      # this machine
      legion-hardware
      legion-gpu
      legion-kernel
      legion-hyprland
    ];

    networking.hostName = "legion";
    system.stateVersion = "24.05"; # Did you read the comment?
    services.printing.enable = true;
    programs.tmux.enable = true;
    security.pam.services.greetd.enableGnomeKeyring = true;

    programs.nix-index-database.comma.enable = true;
    programs.nix-ld.enable = true;
    programs.nix-ld.libraries = with pkgs; [
      ruff
      uv
      libsecret glib # proton-drive CLI session store (gnome-keyring)
    ];
  };
}
