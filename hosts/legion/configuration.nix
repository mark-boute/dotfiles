# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, inputs, ... }:

let
  username = "mark";
in
{
  imports = [ # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./nixos-hardware.nix
    ../../lib
    ../../modules
  ];

  # boot.kernelPackages = pkgs.linuxPackages_zen;
  boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;
  time.hardwareClockInLocalTime = true;

  programs.tmux.enable = true;

  modules = {
    system.gpu.optimus-prime = {
      enable = true;
      mode = "offload";
      cpu = "amd";
      setDeviceIds = true;
      cpuId = "PCI:1:0:0";
      gpuId = "PCI:5:0:0";
      powerManagement = true;
      finegrained = true;
    };

    steam = { enable = true; addprotonup = true; };
    development-tools.r = { enable = true; rstudio = true; };
  };

  environment.systemPackages = with pkgs; [
    # lenovo-legion
    # (callPackage ../../modules/power-options/gtk.nix {})

    powertop
    nvtopPackages.full

    # cloudflare-warp
    gnomeExtensions.cloudflare-warp-indicator
    gnomeExtensions.cloudflare-warp-toggle

    # cora dependencies
    z3
    jdk22
    gradle-completion
    cmake
    unzip
    vscode-extensions.vscjava.vscode-gradle

  ] ++ [
    inputs.zen-browser.packages.${system}.specific
  ];

  # boot.extraModulePackages = with config.boot.kernelPackages; [ lenovo-legion-module ]; 

  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  main-user = {
    enable = true;
    sudoUser = true;
    userName = username;
    description = "Mark Boute";
    shell = pkgs.zsh;
  };

  # Enable numlock on GDM login screen
  programs.dconf.profiles.gdm.databases = [{
    settings."org/gnome/desktop/peripherals/keyboard".numlock-state = true;
  }];

  # home-manager = {
  #   extraSpecialArgs = { inherit inputs; };
  #   users = {
  #     "${username}" = import ./home.nix;
  #   };
  # };

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  services.cloudflare-warp.enable = true;

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Enable the Hyprland compositor
  programs.hyprland.enable = false;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

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

  # List services that you want to enable:

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
}
