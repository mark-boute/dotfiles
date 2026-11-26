{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  flake.nixosConfigurations.marijn-laptop = inputs.nixpkgs.lib.nixosSystem {
    modules = [ nixos.marijn-laptop ];
  };

  flake.modules.nixos.marijn-laptop = { pkgs, ... }: {
    imports = with nixos; [
      # system
      base
      nix
      audio
      scarletto

      # desktop
      gnome

      # applications
      git
      latex
      obsidian
      steam

      # this machine
      marijn-hardware
    ];

    networking.hostName = "marijn-laptop";
    system.stateVersion = "24.05"; # Did you read the comment?

    # REMOVE ONCE ZOTERO IS FIXED!!!
    nixpkgs.config.permittedInsecurePackages = [
      "firefox-esr-140-bin-unwrapped-140.17.0esr"
    ];

    nix.settings = {
      cores = 8;
      max-jobs = 2;
    };

    # inherited from the old shared base
    programs.gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
    warnings = [
      "marijn-laptop: users.groups.libvirtd.members lists \"marijn-laptop\" (the hostname), not the user \"scarletto\", so virt-manager can't manage VMs without root; fix it in hosts/marijn-laptop/default.nix"
      "marijn-laptop: gpg-agent (with SSH support) is on because the old base had it; if you don't use GPG, remove programs.gnupg.agent and this warning from hosts/marijn-laptop/default.nix"
    ];

    services.envfs.enable = true;
    programs.direnv.enable = true;

    virtualisation.docker.enable = true;
    virtualisation.libvirtd.enable = true;
    programs.virt-manager.enable = true;
    users.groups.libvirtd.members = [ "marijn-laptop" ];

    networking.networkmanager.enable = true;
    networking.networkmanager.plugins = with pkgs; [ networkmanager-openvpn ];

    services.printing.enable = true;
    services.printing.drivers = [
      pkgs.hplip
      (pkgs.callPackage ./_km-print/km-print.nix { })
    ];

    environment.etc."samba/smb.conf".text = ''
      [global]
        client min protocol = SMB2
        client max protocol = SMB3
    '';

    hardware.bluetooth.enable = true;

    programs.firefox.enable = true;

    programs.nix-ld.enable = true;
    programs.nix-ld.libraries = with pkgs; [
      # Image stuff
      libsm
      libice
      libx11
      libxcb
      libxkbcommon
      fontconfig
      freetype
      libGL
      glib
      zlib
      libxcb-wm
      libxcb-image
      libxcb-keysyms
      libxcb-render-util
      libxcb-cursor
    ];

    networking.extraHosts = ''
      10.129.127.92 orion.htb
    '';
  };
}
