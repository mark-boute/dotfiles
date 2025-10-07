{
  pkgs,
  main-user,
  lib,
  ...
}: let
  # main-user = "mark";
  wallpaper = ../../home-manager/desktop/hyprland/cappuccino/assets/coffee_pixel_art_2560x1600.png;
  inherit (lib) mkForce;
in {
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = main-user;
  home.homeDirectory = "/home/${main-user}";
  imports = [
    ../../home-manager
  ];

  xdg.portal = {
    extraPortals = mkForce [
      pkgs.xdg-desktop-portal-gtk # For both
      pkgs.xdg-desktop-portal-hyprland # For Hyprland
      pkgs.xdg-desktop-portal-gnome # For GNOME
    ];
  };

  wayland.windowManager.hyprland.settings.monitor = "eDP-1, 2560x1600@240, 0x0, 1";
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
      };
    };
    # eww.enable = true;
    latex.enable = true;
    zsh.enable = true;
    winapps.enable = true;
    spotify.enable = true;
  };

  sops = {
    defaultSopsFile = ../../secrets/${main-user}/${main-user}-secrets.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = "/home/${main-user}/.config/sops/age/keys.txt";
  };

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
    nixd

    authenticator
    eduvpn-client
    bitwarden-cli

    gh
    glab

    # opencpn

    # office suite
    onlyoffice-bin

    # communication
    discord
    signal-desktop-bin
    element-desktop

    lunar-client
    gnomeExtensions.cloudflare-warp-toggle

    # cora dependencies
    z3
    jdk21
    gradle
    # gradle-completion
    # cmake
    # unzip
  ];

  programs = {
    git = {
      enable = true;
      userName = "Mark Boute";
      userEmail = "bmark0702@gmail.com";
      diff-so-fancy.enable = true;

      aliases = {
        s = "status";
        c = "commit";
        b = "switch"; # yep, this is on purpose
        d = "diff";
        l = "log";
        p = "push";
        u = "pull";
        f = "fetch";
        a = "add";
      };

      extraConfig = {
        push = {autoSetupRemote = true;};
        init = {defaultBranch = "main";};
      };
    };

    vscode = {
      enable = true;
      profiles.default = {
        extensions = with pkgs.vscode-extensions; [
          github.copilot

          redhat.java
          vscjava.vscode-java-pack

          catppuccin.catppuccin-vsc
          # catppuccin.catppuccin-vsc-icons

          bierner.markdown-mermaid

          arrterian.nix-env-selector
          jnoortheen.nix-ide

          james-yu.latex-workshop
          tecosaur.latex-utilities

          vue.volar
          hediet.vscode-drawio
        ];
        userSettings = {
          # editor settings
          "editor.semanticHighlighting.enabled" = true;
          "editor.fontFamily" = "JetBrainsMono NF";
          "editor.fontSize" = 14;
          "editor.fontLigatures" = true;
          "editor.cursorBlinking" = "smooth";

          "editor.minimap.autohide" = "mouseover";
          "editor.minimap.maxColumn" = 50;
          "editor.minimap.renderCharacters" = false;
          "editor.minimap.scale" = 2;

          "window.titleBarStyle" = "custom";
          "window.menuBarVisibility" = "visible";

          "github.copilot.enable" = {"*" = true;};
          "git.autofetch" = true;

          # theme settings
          "catppuccin.accentColor" = "rosewater";
          "workbench.colorTheme" = "Catppuccin Macchiato";
          "workbench.iconTheme" = "catppuccin-macchiato";

          # nix
          "nix.formatterPath" = "nixfmt";
          "nix.enableLanguageServer" = true;
          "nix.serverPath" = "nixd";
          "nix.serverSettings" = {
            "nixd.formatting.command" = ["nixfmt"];
            "options" = {
              "nixos.expr" = "(builtins.getFlake \"/home/mark/dotfiles/flake.nix\").nixosConfigurations.legion.options";
              "home-manager.expr" = "(builtins.getFlake \"/home/mark/dotfiles/flake.nix\").homeConfigurations.mark.options";
            };
          };

          # java settings
          "java.jdt.ls.java.home" = "${pkgs.jdk21}";

          # pdf viewer
          "latex-workshop.view.pdf.zoom" = "page-width";
          "latex-workshop.latex.outDir" = "%DIR%/out";
          "latex-workshop.view.pdf.color.dark.backgroundColor" = "#1e2030";
          "latex-workshop.view.pdf.color.dark.pageBorderColor" = "#181926";
          "latex-workshop.view.pdf.color.dark.pageColorsBackground" = "#24273a";
          "latex-workshop.view.pdf.color.dark.pageColorsForeground" = "#cad3f5";

          # markdown preview
          "markdown-preview-enhanced.previewTheme" = "none.css";
          "markdown-preview-enhanced.codeBlockTheme" = "atom-material.css";

          # vscode-drawio
          "hediet.vscode-drawio.appearance" = "automatic";
        };
      };
    };
  };

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

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/mark/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    EDITOR = "nvim";
    NIXOS_OZONE_WLAN = "1";
    NIXOS_OZONE_WL = "1";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "24.05"; # Please read the comment before changing.
}
