{ inputs, ... }:
{
  flake.modules.nixos.mark = { pkgs, ... }: {
    my.user = {
      name = "mark";
      fullName = "Mark Boute";
      email = "mail@markboute.nl";
    };

    users.users.mark.initialPassword = "hello";

    programs.firefox.enable = true;

    my.gnome =
      let
        coffee = "file://${../../../desktop/theme/assets/coffee_pixel_art_2560x1600.png}";
      in
      {
        wallpaper = coffee;
        wallpaperDark = coffee;
        shellBlur = true;
      };

    # plain IDs come from flathub; use { appId; origin; } for other remotes
    services.flatpak.packages = [
      "org.vinegarhq.Sober"
    ];

    home-manager.users.mark = {
      home.stateVersion = "24.05"; # Don't change (dictates initial hm-version)

      home.packages = with pkgs; [
        authenticator
        opencpn

        # proton
        protonmail-desktop
        proton-vpn
        proton-pass
        proton-pass-cli

        # office suite
        onlyoffice-desktopeditors
        typst
        prettypst

        # communication
        discord
        signal-desktop

        inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
      ];
    };
  };
}
