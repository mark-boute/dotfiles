{ pkgs, main-user, ... }:
let
  # main-user = "mark";
in
{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = main-user;
  home.homeDirectory = "/home/${main-user}";
  imports = [ ../../home-manager ];

  modules = {
    gnome-settings.enable = true;
    # hyprland = { enable = true; style = "nord"; };
    # eww.enable = true;
    latex.enable = true;
    zsh.enable = true;
    winapps.enable = true;
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
    vscode
    nixd
    authenticator
    eduvpn-client

    gh
    glab

    opencpn
    
    # office suite
    onlyoffice-bin

    # communication
    discord
    signal-desktop-bin

    spotify

    lunar-client
    gnomeExtensions.cloudflare-warp-toggle
  ];

  programs.git = {
    enable = true;
    userName = "Mark Boute";
    userEmail = "bmark0702@gmail.com";
    diff-so-fancy.enable = true;

    aliases = {
      s = "status";
      c = "commit";
      b = "switch";  # yep, this is on purpose
      d = "diff";
      l = "log";
      p = "push";
      u = "pull";
      f = "fetch";
      a = "add";
    };

    extraConfig = {
      push = { autoSetupRemote = true; };
      init = { defaultBranch = "main"; };
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
