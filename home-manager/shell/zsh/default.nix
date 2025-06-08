{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.modules.zsh;
  inherit (lib) mkEnableOption mkIf;
in {
  options.modules.zsh = {
    enable = mkEnableOption "zsh";

    useStarship = mkEnableOption "starship";
  };

  config = mkIf cfg.enable {
    home.packages = [
      pkgs.zsh

      pkgs.libnotify # dependecy for notify-send
      pkgs.zoxide # the better cd
      pkgs.fzf # zoxide dependecy
      pkgs.nix-output-monitor # colorful nix build outputs
      pkgs.eza # better ls
    ];

    programs.starship = {
      enable = cfg.useStarship;
      settings = {
        add_newline = true;

        git_status = {
          format = "([[$all_status$ahead_behind]]($style) )";
          style = "orange";
        };
      };
    };

    programs.zsh = {
      enable = true;

      # directory to put config files in
      dotDir = ".config/zsh";

      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;

      # .zshrc
      initContent = ''
        source ~/.config/zsh/.p10k.zsh
        bindkey '^R' history-incremental-search-backward
        bindkey '^ ' autosuggest-accept

        eval "$(zoxide init zsh)"
      '';

      # basically aliases for directories:
      # `cd ~dotfiles` will cd into ~/dotfiles
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
        g = "git";
        n = "nom";
        v = "nvim";
        hi = "() { echo $1 ;}";
        nd = "() {nix develop $1 ;}";
        switch = "sudo nixos-rebuild switch --flake ~/dotfiles --fast";
        rebuild = "switch;  notify-send -a NixOS 'Rebuild complete\!'";
        update = "sudo nix flake update --flake ~/dotfiles; switch; notify-send -a NixOS 'System updated\!'";
        #Programs
        cora = "~/.cora/bin/cora";
        cat = "bat -p";
      };

      # Source all plugins, nix-style
      plugins = [
        # to be replaced with ohmyposh
        {
          name = "powerlevel10k";
          src = pkgs.zsh-powerlevel10k;
          file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
        }
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
