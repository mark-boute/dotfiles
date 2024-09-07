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
    ../../lib
    ../../modules
  ];

  main-user = {
    enable = true;
    sudoUser = true;
    userName = username;
    description = "Mark Boute";
  };

  modules = {
    system.gpu.optimus-prime = {
      enable = true;
      mode = "offload";
      cpu = "intel";
      setDeviceIds = true;
      cpuId = "PCI:0:2:0";
      gpuId = "PCI:1:0:0";
    };

    steam = { enable = true; addprotonup = true; };
    development-tools.r = { enable = true; rstudio = true; };
  };

  programs = {
    tmux.enable = true;
    firefox.enable = true;
  };

  # Enable numlock on GDM login screen
  programs.dconf.profiles.gdm.databases = [{
    settings."org/gnome/desktop/peripherals/keyboard".numlock-state = true;
  }];

  # Enable networking
  networking.networkmanager.enable = true;

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment and GDM
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Enable the COSMIC Desktop Environment without cosmic-greeter
  services.desktopManager.cosmic.enable = true;
  services.displayManager.cosmic-greeter.enable = false;

  # Enable the Hyprland compositor
  programs.hyprland.enable = true;

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

}
