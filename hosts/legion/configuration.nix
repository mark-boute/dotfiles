{
  self,
  config,
  system,
  pkgs,
  inputs,
  main-user,
  lib,
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
  boot.extraModulePackages = [ config.boot.kernelPackages.lenovo-legion-module ];
  time.hardwareClockInLocalTime = true;

  programs = {
    thunderbird.enable = true;
    tmux.enable = true;
    hyprland = {
      enable = true;
      withUWSM = true;
      xwayland.enable = true;
    };
    uwsm = {
      enable = true;
      waylandCompositors.hyprland = {
        prettyName = "Hyprland";
        comment = "Hyprland compositor managed by UWSM";
        binPath = "/run/current-system/sw/bin/Hyprland";
      };
    };
    firefox.enable = true;
  };

  xdg.portal = {
    enable = true;
    wlr.enable = false;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk # Fallback
      pkgs.xdg-desktop-portal-hyprland # For Hyprland
    ];

    config = {
      common = {
        default = ["*"];
        "org.freedesktop.portal.Settings" = ["hyprland"];
        "org.freedesktop.portal.ScreenCast" = ["hyprland"];
        "org.freedesktop.portal.Screenshot" = ["hyprland"];
        "org.freedesktop.impl.portal.Secret" = ["gnome-keyring"];
        "org.freedesktop.impl.portal.FileChooser" = ["hyprland"];
        "org.freedesktop.portal.OpenURI" = ["hyprland"];
      };
      hyprland = {
        default = [ "hyprland" ];
        "org.freedesktop.impl.portal.Settings" = [ "gtk" ];
      };
    };
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

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    WLR_NO_HARDWARE_CURSORS = "1";
    GSETTINGS_SCHEMA_DIR = "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}";

    # XDG and Portal integration
    GTK_USE_PORTAL = "1";
    NIXOS_XDG_OPEN_USE_PORTAL = "1";
    XDG_SESSION_TYPE = "wayland";
    XDG_CURRENT_DESKTOP = "Hyprland";

    # QT Wayland integration
    QT_QPA_PLATFORM = "wayland";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";

    # Additional Wayland compatibility
    MOZ_ENABLE_WAYLAND = "1";
    _JAVA_AWT_WM_NONREPARENTING = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";

  };
  environment.systemPackages = with pkgs;
    [

      quickshell

      # system monitoring
      lenovo-legion
      powertop
      htop
      # nvtopPackages.full

      nixfmt

      nvchad

      # windown emulation
      # winboat
      # freerdp

      uv
      dotnetCorePackages.sdk_9_0
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

  hardware.enableRedistributableFirmware = true;
  networking.firewall.allowedTCPPorts = [ 25565 ];
  networking.networkmanager = {
    settings = {
      device."wifi.scan-rand-mac-address" = "no";
      connection."wifi.cloned-mac-address" = "permanent";
    };

    plugins = with pkgs; [ 
      networkmanager-openvpn # support for EduVPN
    ];
  };

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    ruff
    uv
  ];

  hardware.bluetooth.enable = true;
  security = {
    rtkit.enable = true;
    pam.services = {
      greetd.enableGnomeKeyring = true;
    };
  };

  services = {
    cloudflare-warp.enable = true;
    printing.enable = true;
    pulseaudio.enable = false;
    libinput.enable = true;
    flatpak = {
      enable = true;
      remotes = lib.mkOptionDefault [
        {
          name = "flathub-beta"; 
          location = "https://flathub.org/beta-repo/flathub-beta.flatpakrepo";
        }
      ];
      packages = [
        { appId = "org.vinegarhq.Sober"; origin = "flathub"; }
        { appId = "app.eduroam.geteduroam"; origin = "flathub"; }
      ];
    };
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
    gnome.gnome-keyring.enable = true;

    xserver.enable = true;
    xserver.xkb = {
      # Configure keymap in X11
      layout = "us";
      variant = "";
    };
  };
}
