{
  self,
  config,
  system,
  pkgs,
  inputs,
  main-user,
  ...
}: let
in {
  imports = [
    ./hardware-configuration.nix
    ./nixos-hardware.nix
  ];

  main-user = {
    enable = true;
    sudoUser = true;
    userName = main-user;
    description = "Mark Boute";
    shell = pkgs.zsh;
    groups = ["docker"];
  };

  virtualisation.docker.enable = true;
  hardware.nvidia-container-toolkit.enable = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.extraModulePackages = [ config.boot.kernelPackages.lenovo-legion-module ];
  time.hardwareClockInLocalTime = true;

  programs = {
    thunderbird.enable = true;
    tmux.enable = true;
    hyprland = {
      enable = true;
      withUWSM = false;
      xwayland.enable = true;
    };
    firefox.enable = true;
  };

  catppuccin = {
    enable = true;
    cache.enable = true;
    flavor = "macchiato";
    accent = "rosewater";

    cursors.enable = true;
    grub.enable = true;
    gtk.icon.enable = true;
  };

  modules = {
    system.gpu.optimus-prime = {
      enable = true;
      mode = "offload";
      cpu = "amd";
      open = true;
      setDeviceIds = true;
      integratedGraphicsId = "PCI:6:0:0";
      dedicatedGraphicsId = "PCI:1:0:0";
      powerManagement = true;
      finegrained = false;
      # nvidiaPackage = config.boot.kernelPackages.nvidiaPackages.latest;

      # nvidiaPackage = config.boot.kernelPackages.nvidiaPackages.mkDriver {
      #   version = "580.65.06";
      #   sha256_64bit = "sha256-BLEIZ69YXnZc+/3POe1fS9ESN1vrqwFy6qGHxqpQJP8=";
      #   sha256_aarch64 = "sha256-4CrNwNINSlQapQJr/dsbm0/GvGSuOwT/nLnIknAM+cQ=";
      #   openSha256 = "sha256-BKe6LQ1ZSrHUOSoV6UCksUE0+TIa0WcCHZv4lagfIgA=";
      #   settingsSha256 = "sha256-9PWmj9qG/Ms8Ol5vLQD3Dlhuw4iaFtVHNC0hSyMCU24=";
      #   persistencedSha256 = "sha256-ETRfj2/kPbKYX1NzE0dGr/ulMuzbICIpceXdCRDkAxA=";

      #   ibtSupport = true;
      # };
    };
    steam = {
      enable = true;
      addprotonup = true;
    };
    sops.enable = true;
  };

  # environment.sessionVariables.NIXOS_OZONE_WL = "1";
  environment.systemPackages = with pkgs;
    [
      # system monitoring
      lenovo-legion
      powertop
      htop
      # nvtopPackages.full

      nixfmt-rfc-style

      nvchad

      # windown emulation
      # winboat
      # freerdp
    ]
    ++ [
      # self.packages.${pkgs.stdenv.hostPlatform.system}.neovim-mark
    ];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

  # Enable numlock on GDM login screen
  programs.dconf.profiles.gdm.databases = [
    {
      settings."org/gnome/desktop/peripherals/keyboard".numlock-state = true;
    }
  ];

  networking.networkmanager = {
    enable = true;
    plugins = with pkgs; [ 
      networkmanager-openvpn # support for EduVPN
    ];
  };

  hardware.bluetooth.enable = true;
  security.rtkit.enable = true;

  services = {
    cloudflare-warp.enable = true;
    printing.enable = true;
    pulseaudio.enable = false;
    libinput.enable = true;

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      # If you want to use JACK applications, uncomment this
      #jack.enable = true;
    };

    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;

    xserver.enable = true;
    xserver.xkb = {
      # Configure keymap in X11
      layout = "us";
      variant = "";
    };
  };
}
