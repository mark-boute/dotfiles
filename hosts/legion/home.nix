{
  pkgs,
  main-user,
  lib,
  inputs,
  ...
}: let
  wallpaper = ../../home-manager/desktop/hyprland/cappuccino/assets/coffee_pixel_art_2560x1600.png;
  inherit (lib) mkForce;
in {
  home.username = main-user;
  home.homeDirectory = "/home/${main-user}";
  imports = [
    ../../home-manager
    ./mark/git.nix
    ./mark/vscode.nix
  ];

  xdg.portal = {
    enable = true;
    extraPortals = mkForce [
      pkgs.xdg-desktop-portal-gtk # For both
      pkgs.xdg-desktop-portal-hyprland # For Hyprland
      pkgs.xdg-desktop-portal-gnome # For GNOME
    ];
  };

  wayland.windowManager.hyprland.settings.monitor = [
    # Laptop panel (internal)
    "desc:California Institute of Technology 0x1637 0x00006000, 2560x1600@240, 0x0, 1.25" # , bitdepth, 10" #, cm, hdr, sdrbrightness, 1.4, sdrsaturation, 0.8"

    # HDMI ultrawide external monitor
    "desc:Philips Consumer Electronics Company 34M2C3500L UK02514050797, 3440x1440@100, 2048x-160, 1, bitdepth, 10"
    "desc:Samsung Electric Company SAMSUNG, 1920x1080@60, auto, 1, mirror, eDP-1"
  ];

  modules = {
    gnome-settings = {
      enable = true;
      useCatppuccin = true;
      background-light = "file://${wallpaper}";
      background-dark = "file://${wallpaper}";
      shellBlur = true;
    };
    hyprland = {
      enable = true;
      configuration = "cappuccino";
      super-key = "SUPER";
      shared = {
        keybinds.enable-all = true;
        hyprdynamicmonitors.enable = true;
      };
    };
    zsh = {
      enable = true;
      usePowerlevel10k = true;
      enableNH = true;
    };
    latex.enable = true;
    spotify.enable = true;
  };

  catppuccin = {
    enable = true;
    cache.enable = true;
    flavor = "macchiato";
    accent = "rosewater";

    bat.enable = true;
    chromium.enable = true;
    cursors.enable = true;
    firefox.enable = true;
    hyprland.enable = true;
    kitty.enable = true;
    hyprlock.enable = true;
    nvim.enable = true;
    starship.enable = true;
    thunderbird.enable = true;
    vesktop.enable = true;
  };

  sops = {
    defaultSopsFile = ../../secrets/${main-user}/${main-user}-secrets.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = "/home/${main-user}/.config/sops/age/keys.txt";
  };

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs;
    [
      # # It is sometimes useful to fine-tune packages, for example, by applying
      # # overrides. You can do that directly here, just don't forget the
      # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
      # # fonts?
      # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

      nixd
      nix-inspect

      # networking and authentication
      gnomeExtensions.cloudflare-warp-toggle
      authenticator
      eduvpn-client
      bitwarden-cli

      gh
      glab
      opencpn

      # gaming
      # flightgear
      r2modman      
      lunar-client
      prismlauncher

      # office suite
      onlyoffice-desktopeditors
      gimp

      plex-desktop

      # communication
      discord
      # vesktop
      signal-desktop-bin
      # element-desktop

      # cora dependencies
      z3
      jdk21
      gradle
    ]
    ++ [
      inputs.zen-browser.packages.${pkgs.stdenv.system}.default
    ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    NIXOS_OZONE_WLAN = "1";
    NIXOS_OZONE_WL = "1";
  };

  programs.home-manager.enable = true; # Let Home Manager install and manage itself.
  home.stateVersion = "24.05"; # Don't change (dictates initial hm-version)
}
