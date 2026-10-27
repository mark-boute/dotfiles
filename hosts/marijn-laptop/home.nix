{ config, pkgs, inputs, ... }:

{
  home.username = "scarletto";
  home.homeDirectory = "/home/scarletto";
  imports = [ ../../home-manager ];

  modules = {
    gnome-settings.enable = true;
    gnome-settings.preferLight = true;
    # hyprland = { enable = true; style = "nord"; };
    # eww.enable = true;
    latex.enable = true;
    # astrovim.enable = true;
  };

  home.packages = with pkgs; [ 
    vscode
    typst

    gh
    glab
    # zotero
    
    discord
    signal-desktop
    slack

    gimp
    ffmpeg

    zen-browser
    
    eduvpn-client        
    openvpn

    # rpi-imager
    openscad
    orca-slicer

    hplip
    usbutils
  ] ++
  lib.optional (system != "aarch64-linux") (
    lib.warnIfNot (lib.hasInfix "-firefox-esr-140-bin-unwrapped-" zotero.buildPhase)
      "EXPIRING OVERRIDE: zotero no longer bundles firefox-esr-140-bin-unwrapped. Remove it from configuration.nix!"
      zotero
  );

  programs.git = {
    enable = true;
    settings = {
      user.name = "Marijn Meuleman";
      user.email = "marijn2312@gmail.com";
      aliases = {
        s = "status";
        c = "commit";
        b = "switch";  # yep, this is on purpose
        d = "diff";
        l = "log";
        p = "push";
        f = "fetch";
        a = "add";
      };
      push = { autoSetupRemote = true; };
    };
  };    
  
  programs.diff-so-fancy.enable = true;

  programs.obsidian = {
    enable = true;
    vaultEnvs.enable = true;
    vaultEnvs.hideNormalApp = true;
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
