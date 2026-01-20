{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.modules.zsh;
  inherit (lib) mkEnableOption mkIf mkMerge;

  # function converting ~/ to absolute path
  expandHome = path: lib.optionalString (path != null) (
    if lib.strings.hasPrefix "~/" path
      then "${config.home.homeDirectory}${lib.removePrefix "~" path}"
      else path
  );
in {
  options.modules.zsh = {
    enable = mkEnableOption "zsh";

    enableNH = mkEnableOption "home-manager NH shell integration";

    flakePath = lib.mkOption {
      type = lib.types.nullOr(lib.types.str);
      default = "~/dotfiles";
      description = "Path to the dotfiles flake for nh integration.";
    };

    osFlakePath = lib.mkOption {
      type = lib.types.nullOr(lib.types.str);
      default = null;
      description = "Path to the os flake for nh integration.";
    };

    homeFlakePath = lib.mkOption {
      type = lib.types.nullOr(lib.types.str);
      default = null;
      description = "Path to the home-manager flake for nh integration.";
    };

    useStarship = mkEnableOption "starship";
    usePowerlevel10k = mkEnableOption "powerlevel10k";
  };

  config = mkMerge [
    (mkIf cfg.enableNH {
      programs.nh = {
        enable = true;
        clean.enable = true;
        clean.extraArgs = "--keep-since 7d --keep 3";
        flake = expandHome cfg.flakePath;
        osFlake = expandHome cfg.osFlakePath;
        homeFlake = expandHome cfg.homeFlakePath;
      };
    })

    (mkIf (cfg.useStarship && cfg.enable) {
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
    })

    (mkIf (cfg.usePowerlevel10k && cfg.enable) {
      programs.starship.enable = false;

      programs.zsh.plugins = [{
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }];

      # add .p10k.zsh to ~/.config/zsh/
      xdg.configFile."zsh/.p10k.zsh".source = ./.p10k.zsh;
    })

    (mkIf cfg.enable {
      home.packages = [
        pkgs.zsh
        pkgs.libnotify # dependecy for notify-send
        pkgs.zoxide # the better cd
        pkgs.fzf # zoxide dependecy
        pkgs.nix-output-monitor # colorful nix build outputs
        pkgs.eza # better ls
      ];

      programs.zsh = {
        enable = true;

        # directory to put config files in
        dotDir = config.home.homeDirectory + "/.config/zsh";

        enableCompletion = true;
        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;

        # .zshrc
        initContent = ''
          source ~/.config/zsh/.p10k.zsh
          bindkey '^R' history-incremental-search-backward
          bindkey '^ ' autosuggest-accept

          eval "$(zoxide init zsh)"

          [ "$TERM" = "xterm-kitty" ] && alias s="kitty +kitten ssh"
        '';

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
          ni = "nix-inspect --expr 'builtins.getFlake (import ${expandHome cfg.flakePath}/flake.nix)'";
 
          # Nix
          switch = if cfg.enableNH 
            then "sudo -v && nh os switch"
            else "sudo nixos-rebuild switch --flake ${cfg.flakePath} --no-reexec";

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
    })
  ];
}
