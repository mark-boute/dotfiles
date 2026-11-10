{ config, inputs, ... }:
{
  flake.modules.nixos.catppuccin = { pkgs, ... }:
  let
    grubLogo = ./assets/coffee_pixel.png;
    logoSize = 600;
    resizeFactor = 0.25; # fraction of the original size
    customGrubTheme = pkgs.runCommand "catppuccin-macchiato-grub-coffee" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
      cp -r ${pkgs.catppuccin-grub.override { flavor = "macchiato"; }} $out
      chmod -R u+w $out
      magick ${grubLogo} -resize ${toString (builtins.floor (resizeFactor * 100))}% $out/logo.png
      substituteInPlace $out/theme.txt \
        --replace "left = 50%-50" "left = 50%-${toString (builtins.floor (logoSize * resizeFactor / 2))}" \
        --replace "top = 50%-50" "top = 50%-${toString (builtins.floor (logoSize * resizeFactor / 2))}"
    '';
  in
  {
    imports = [ inputs.catppuccin.nixosModules.catppuccin ];

    home-manager.sharedModules = [ config.flake.modules.homeManager.catppuccin ];

    programs.dconf.profiles.gdm.databases = [
      {
        settings."org/gnome/desktop/interface" = {
          gtk-theme = "catppuccin-macchiato-rosewater-standard";
          color-scheme = "prefer-dark";
        };
      }
    ];

    catppuccin = {
      enable = true;
      autoEnable = true;
      cache.enable = true;
      flavor = "macchiato";
      accent = "rosewater";

      cursors.enable = true;
      grub.enable = false;
      gtk.icon.enable = true;
    };

    boot.loader.grub.theme = customGrubTheme;

    fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];
  };

  flake.modules.homeManager.catppuccin = { pkgs, lib, config, ... }:
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
    imports = [ inputs.catppuccin.homeModules.catppuccin ];

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
      vesktop.enable = true;
      spotify-player.enable = true;
    };

    # catppuccin's own cursors module (modules/home-manager/cursors.nix) sets
    # home.pointerCursor.name/package but not .enable — home-manager now wants
    # that explicit, hence this on its own.
    home.pointerCursor.enable = true;

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
      gtk4.theme = config.gtk.theme;
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
  };
}
