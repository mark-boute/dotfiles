{ pkgs, lib, config, ... }:
with lib; let 
  cfg = config.modules.zsh;
in {
  options.modules.zsh = { enable = mkEnableOption "zsh"; };

  config = mkIf cfg.enable {
    home.packages = [
      pkgs.zsh
      pkgs.libnotify
      pkgs.zoxide
      pkgs.fzf
    ];

    programs.zsh = {
      enable = true;

      # directory to put config files in
      dotDir = ".config/zsh";

      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;

      # .zshrc
      initExtra = ''
        PROMPT="%F{blue}%m %~%b "$'\n'"%(?.%F{green}%Bλ%b |.%F{red}?) %f"
        bindkey '^R' history-incremental-search-backward
        bindkey '^ ' autosuggest-accept
        eval "$(zoxide init zsh)"
      '';

      # basically aliases for directories: 
      # `cd ~dots` will cd into ~/.config/nixos
      dirHashes = {
        dotfiles = "$HOME/dotfiles";
      };

      # Tweak settings for history
      history = {
        save = 10000;
        size = 10000;
        path = "$HOME/.cache/zsh_history";
      };

      # Set some aliases
      shellAliases = {
        c = "clear";
        mkdir = "mkdir -vp";
        rm = "rm -rifv";
        mv = "mv -iv";
        cp = "cp -riv";
        ls = "ls -lah";
        #Devops
        nd = "nix develop -c $SHELL";
        rebuild = "sudo nixos-rebuild switch --flake ~/dotfiles --fast;  notify-send -a NixOS 'Rebuild complete\!'";
        #Programs
      };

      # Source all plugins, nix-style
      plugins = [
        {
          name = "auto-ls";
          src = pkgs.fetchFromGitHub {
            owner = "notusknot";
            repo = "auto-ls";
            rev = "62a176120b9deb81a8efec992d8d6ed99c2bd1a1";
            sha256 = "08wgs3sj7hy30x03m8j6lxns8r2kpjahb9wr0s0zyzrmr4xwccj0";
          };
        }
      ];
    };
  };
}