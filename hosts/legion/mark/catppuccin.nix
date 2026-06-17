{pkgs, ...}:
{
  catppuccin = {
    enable = true;
    autoEnable = true;
    cache.enable = true;
    flavor = "macchiato";
    accent = "rosewater";
    cursors.enable = true;

    hyprland.enable = true;
    hyprlock.enable = true;
    hyprtoolkit.enable = true;

    qt5ct.enable = true;
    gtk.icon.enable = true;
    kvantum.enable = true;

    kitty.enable = true;
    starship.enable = true;
    nvim.enable = true;
    bat.enable = true;
    vscode.profiles.default.enable = true;

    chromium.enable = true;
    firefox.enable = true;

    element-desktop.enable = true;
    thunderbird.enable = true;
    vesktop.enable = true;
    spotify-player.enable = true;
  };

  gtk = {
    enable = true;
    theme = {
      name = "catppuccin-macchiato-rosewater-standard-default";
      package = pkgs.catppuccin-gtk.override {
        accents = [ "rosewater" ];
        size = "standard";
        variant = "macchiato";
      };
    };

    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
  };

  qt = {
    enable = true;
    platformTheme.name = "qtct";
    style.name = "kvantum";
  };

  home.packages = with pkgs; [
    libsForQt5.qt5ct
    kdePackages.qt6ct
    libsForQt5.qtstyleplugin-kvantum
    kdePackages.qtstyleplugin-kvantum
  ];

  home.sessionVariables = {
    GTK_THEME = "catppuccin-macchiato-rosewater-standard-default";
  };
}