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
    # ./openvpn.nix
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
      open = true;
      setDeviceIds = true;
      cpuId = "PCI:1:0:0";
      gpuId = "PCI:5:0:0";
      powerManagement = false;
      finegrained = true;
      nvidiaPackage = config.boot.kernelPackages.nvidiaPackages.beta;
    };

    steam = { enable = true; addprotonup = true; };
  };

  environment.systemPackages = with pkgs; [
    # lenovo-legion
    # (callPackage ../../modules/power-options/gtk.nix {})

    powertop
    nvtopPackages.full

    # cloudflare-warp
    gnomeExtensions.cloudflare-warp-indicator
    gnomeExtensions.cloudflare-warp-toggle

    # eduvpn-client

    # navigation
    opencpn

    # office suite
    libreoffice

    # cora dependencies
    z3
    jdk23
    gradle-completion
    cmake
    unzip

    vscode-fhs
    (vscode-with-extensions.override {
      vscodeExtensions = with vscode-extensions; [
        bbenoist.nix
        ms-python.python
        ms-azuretools.vscode-docker
        ms-vscode-remote.remote-ssh
        vscjava.vscode-java-pack
        vscjava.vscode-gradle
      ] ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
        {
          name = "remote-ssh-edit";
          publisher = "ms-vscode-remote";
          version = "0.47.2";
          sha256 = "1hp6gjh4xp2m1xlm1jsdzxw9d8frkiidhph6nvl24d0h8z34w49g";
        }
      ];
    })
  ] ++ [
    inputs.zen-browser.packages.${system}.default
  ];

  virtualisation.docker.enable = true;

  # boot.extraModulePackages = with config.boot.kernelPackages; [ lenovo-legion-module ]; 

  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  main-user = {
    enable = true;
    sudoUser = true;
    userName = username;
    description = "Mark Boute";
    shell = pkgs.zsh;
    groups = ["docker"];
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
