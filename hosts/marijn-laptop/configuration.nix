# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, inputs, ... }:

let
  username = "scarletto";
in
{
  # REMOVE ONCE ZOTERO IS FIXED!!!
  nixpkgs.config.permittedInsecurePackages = [
    "firefox-esr-140-bin-unwrapped-140.17.0esr"
  ];

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      trusted-users = [ "@wheel" ];
      cores = 8;
      max-jobs = 2;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };
  imports = [ # Include the results of the hardware scan.
    ./hardware-configuration.nix
    inputs.nixos-hardware.nixosModules.lenovo-ideapad-15alc6
    ../../lib
    ../../modules
  ];
    
  programs.bash = {
    enable = true;
    shellAliases = {
      n-rebuild = "sudo nixos-rebuild switch --flake ~/dotfiles";
      n-update = "sudo nix flake update --flake ~/dotfiles && sudo nixos-rebuild switch --flake ~/dotfiles";
      n-config = "nano ~/dotfiles/hosts/marijn-laptop/configuration.nix";
      n-home = "nano ~/dotfiles/hosts/marijn-laptop/home.nix";
      n-env = "nix develop";
      n-flake-generate = "cp ~/dotfiles/hosts/marijn-laptop/blank_flake ./flake.nix && nano ./flake.nix";
      n-flake = "nano ./flake.nix";
      n-direnv-generate = "touch .envrc && echo \"use flake\" > .envrc && nano ./.envrc";
      n-direnv-allow = "direnv allow";
      n-direnv = "nano ./.envrc";
    };
  };
  services.envfs.enable = true;
  
  # Enable direnvs
  programs.direnv.enable = true;

  modules = {
    steam = { enable = true; addprotonup = true; };
  };

  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  main-user = {
    enable = true;
    sudoUser = true;
    userName = username;
    description = "Marijn Meuleman";
    groups = [ "dialout"  "docker" ];
  };

  virtualisation.docker.enable = true;
  
  # Enable numlock on GDM login screen
  programs.dconf.profiles.gdm.databases = [{
    settings."org/gnome/desktop/peripherals/keyboard".numlock-state = true;
  }];

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;
  networking.networkmanager.plugins = with pkgs; [ networkmanager-openvpn ];

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Enable the Hyprland compositor
  # programs.hyprland.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;
  services.printing.drivers = with pkgs; [
    hplip
    km-print
  ];

  environment.etc."samba/smb.conf".text = ''
    [global]
      client min protocol = SMB2
      client max protocol = SMB3
  '';

  # Enable bluetooth
  hardware.bluetooth.enable = true;

  # Enable sound with pipewire.
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;

  # Install firefox.
  programs.firefox.enable = true;
  
  programs.nix-ld.enable = true;

  programs.nix-ld.libraries = with pkgs; [
    # UV
    codeql ruff uv
    # Image stuff
    xorg.libSM xorg.libICE xorg.libX11 xorg.libxcb libxkbcommon fontconfig freetype libGL glib zlib xorg.xcbutilwm xorg.xcbutilimage xorg.xcbutilkeysyms xorg.xcbutilrenderutil libxcb-cursor
  ];

  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;
  users.groups.libvirtd.members = ["marijn-laptop"];


  # List services that you want to enable:

  networking.extraHosts = 
  ''
    10.129.127.92 orion.htb
  '';
  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
}
