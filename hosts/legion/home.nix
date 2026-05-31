{
  pkgs,
  config,
  main-user,
  inputs,
  ...
}: let
  wallpaper = ../../home-manager/desktop/hyprland/cappuccino/assets/coffee_pixel_art_2560x1600.png;
in {
  home.username = main-user;
  home.homeDirectory = "/home/${main-user}";
  imports = [
    ../../home-manager

    ./mark/git.nix
    ./mark/vscode.nix
    ./mark/hyprmonitors.nix
    ./mark/catppuccin.nix
  ];
  gtk.gtk4.theme = config.gtk.theme;

  modules = {
    gnome-settings = {
      enable = true;
      useCatppuccin = true;
      background-light = "file://${wallpaper}";
      background-dark = "file://${wallpaper}";
      shellBlur = true;
    };
    hyprland.enable = true;
    hyprland.cappuccino.enable = true;
    zsh = {
      enable = true;
      usePowerlevel10k = true;
      enableNH = true;
      enableDirenv = true;
      useNixDirenv = true;
    };
    latex.enable = true;
    spotify.enable = true;
  };

  sops = {
    defaultSopsFile = ../../secrets/${main-user}/${main-user}-secrets.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = "/home/${main-user}/.config/sops/age/keys.txt";
  };

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
      r2modman      
      lunar-client
      prismlauncher

      # office suite
      onlyoffice-desktopeditors
      typst
      prettypst
      hledger
      hledger-ui
      hledger-web

      plex-desktop

      # communication
      discord
      vesktop
      signal-desktop
      element-desktop

      # cora dependencies
      z3
      jdk21
      gradle
    ]
    ++ [
      inputs.zen-browser.packages.${pkgs.stdenv.system}.default
    ];

  home.sessionVariables = {
    EDITOR = "nvim";
    NIXOS_OZONE_WLAN = "1";
    NIXOS_OZONE_WL = "1";
  };

  programs.home-manager.enable = true; # Let Home Manager install and manage itself.
  home.stateVersion = "24.05"; # Don't change (dictates initial hm-version)
}
