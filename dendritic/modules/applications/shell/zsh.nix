{ config, ... }:
let
  inherit (config.flake.modules) homeManager;
in
{
  flake.modules.nixos.zsh = { config, pkgs, ... }: {
    home-manager.sharedModules = [ homeManager.zsh ];

    programs.zsh.enable = true;
    environment.shells = [ pkgs.zsh ];
    users.users.${config.my.user.name}.shell = pkgs.zsh;
    system.userActivationScripts.zshrc = "touch .zshrc";
  };

  flake.modules.homeManager.zsh = { config, osConfig, pkgs, ... }:
  let
    flake = osConfig.my.flakeDir;
  in
  {
    programs.nh = {
      enable = true;
      clean.enable = true;
      clean.extraArgs = "--keep-since 7d --keep 3";
      inherit flake;
    };

    programs.direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };

    programs.starship.enable = false;

    home.sessionVariables.EDITOR = "nvim";

    home.packages = [
      pkgs.zsh
      pkgs.libnotify # dependecy for notify-send
      pkgs.zoxide # the better cd
      pkgs.fzf # zoxide dependecy
      pkgs.nix-output-monitor # colorful nix build outputs
      pkgs.eza # better ls
    ];

    xdg.configFile."zsh/.p10k.zsh".source = ./.p10k.zsh;

    programs.zsh = {
      enable = true;

      dotDir = config.home.homeDirectory + "/.config/zsh";

      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;

      initContent = ''
        source ~/.config/zsh/.p10k.zsh
        bindkey '^R' history-incremental-search-backward
        bindkey '^ ' autosuggest-accept

        eval "$(zoxide init zsh)"

        [ "$TERM" = "xterm-kitty" ] && alias s="kitty +kitten ssh"
      '';

      history = {
        save = 10000;
        size = 10000;
        path = "$HOME/.cache/zsh_history";
      };

      shellAliases = {
        c = "clear";
        mkdir = "mkdir -vp";
        rm = "rm -rifv";
        mv = "mv -iv";
        cp = "cp -riv";
        ls = "ls -lah";

        #Devops
        g = "git";
        gs = "git status";
        ga = "git add";
        gc = "git commit";
        gp = "git push";
        gu = "git pull";
        gd = "git diff";
        gb = "git switch";
        n = "nom";
        v = "nvim";
        nd = "() {nix develop -c $SHELL $1 ;}";
        ns = "nix-shell --run $SHELL";
        ni = "nix-inspect --expr 'builtins.getFlake (import ${flake}/flake.nix)'";

        # Nix
        switch = "sudo -v && nh os switch ${flake}";
        rebuild = "switch && notify-send -a NixOS 'Rebuild complete\!'";
        update = "sudo -v && nh os switch -u ${flake} && notify-send -a NixOS 'System updated\!'";

        #Programs
        cora = "~/.cora/bin/cora";
        proton-drive = "~/.proton-drive/bin/proton-drive";
        cat = "bat -p";
      };

      plugins = [
        {
          name = "powerlevel10k";
          src = pkgs.zsh-powerlevel10k;
          file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
        }
        # to be replaced with ohmyposh
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
