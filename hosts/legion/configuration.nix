{
  self,
  config,
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
  boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;
  boot.extraModulePackages = [ config.boot.kernelPackages.lenovo-legion-module ];
  time.hardwareClockInLocalTime = true;

  programs = {
    thunderbird.enable = true;
    tmux.enable = true;
    hyprland.enable = true;
    firefox.enable = true;
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
      finegrained = true;
      nvidiaPackage = config.boot.kernelPackages.nvidiaPackages.beta;
    };
    steam = {
      enable = true;
      addprotonup = true;
    };
    winapps.enable = true;
    sops.enable = true;
  };

  # environment.sessionVariables.NIXOS_OZONE_WL = "1";
  environment.systemPackages = with pkgs;
    [
      lenovo-legion
      powertop
      nvtopPackages.full

      nixfmt-rfc-style
    ]
    ++ [
      inputs.zen-browser.packages.${system}.default
      self.packages.${system}.neovim-mark
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

    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;

    xserver.xkb = {
      # Configure keymap in X11
      layout = "us";
      variant = "";
    };

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      # If you want to use JACK applications, uncomment this
      #jack.enable = true;
    };
  };
}
