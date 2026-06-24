{pkgs, lib, config, ...}:
let
  # catppuccin's qtct conf omits icon_theme, so Qt apps resolve no named icons.
  qtctConf = pkgs.writeText "qtct.conf" ''
    [Appearance]
    color_scheme_path=${pkgs.catppuccin-qt5ct}/catppuccin-${config.catppuccin.flavor}-${config.catppuccin.accent}.conf
    custom_palette=true
    icon_theme=Papirus-Dark
  '';
in
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
      name = "catppuccin-macchiato-rosewater-standard";
      package = pkgs.catppuccin-gtk.override {
        accents = [ "rosewater" ];
        size = "standard";
        variant = "macchiato";
      };
    };

    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
  };

  # GNOME (gnome-tweaks / Settings) rewrites these as real files at runtime,
  # which collides with home-manager's backup-on-activate. Force overwrite so
  # activation never aborts trying to back up to an already-existing *.backup.
  xdg.configFile."gtk-4.0/settings.ini".force = true;
  xdg.configFile."gtk-4.0/gtk.css".force = true;

  qt = {
    enable = true;
    platformTheme.name = "qtct";
    style.name = "kvantum";
  };

  # mkForce overrides catppuccin's own `.source` for these confs.
  xdg.configFile."qt5ct/qt5ct.conf".source = lib.mkForce qtctConf;
  xdg.configFile."qt6ct/qt6ct.conf".source = lib.mkForce qtctConf;

  home.packages = with pkgs; [
    libsForQt5.qt5ct
    kdePackages.qt6ct
    libsForQt5.qtstyleplugin-kvantum
    kdePackages.qtstyleplugin-kvantum
  ];

  home.sessionVariables = {
    GTK_THEME = "catppuccin-macchiato-rosewater-standard";
  };
}