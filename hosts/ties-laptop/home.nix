{ config, pkgs, ... }:

{
  imports = [ ../../home-manager ];
  modules = {
    gnome-settings = {enable = true; 
                      background-dark = file:///nix/store/z6mpfb1r6w7rzq04p9fkvvy8090050v7-simple-dark-gray-2016-02-19/share/backgrounds/nixos/nix-wallpaper-simple-dark-gray.png ; 
                      background-light = file:///nix/store/pn4ahzf7bvws0fa7aifhw7ljksbc69j3-simple-blue-2016-02-19/share/backgrounds/nixos/nix-wallpaper-simple-blue.png;};
    # hyprland = { enable = true; style = "nord"; };
    # eww.enable = true;
    # latex.enable = true;
  };

  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "tiesd";
  home.homeDirectory = "/home/tiesd";
  nixpkgs.config.allowUnfree = true;

  # wayland.windowManager.hyprland = {
  #   enable = true;
  #   settings = {
  #     "$mod" = "SUPER";
  #     bind = [
  #       "$mod, W, exec, firefox"
	#       "$mod, T, exec, kitty"
  #     ];
  #   };
  #   systemd.variables = ["--all"];
  # };

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = [
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
    pkgs.vscode
    pkgs.gh
    pkgs.discord
    pkgs.vesktop
    pkgs.brave
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


  programs.git = {
    enable = true;
    userName = "Ties Dirksen";
    userEmail = "tiesdirksen@gmail.com";
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
    # EDITOR = "emacs";
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
