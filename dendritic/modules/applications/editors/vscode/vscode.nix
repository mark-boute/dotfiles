{ config, ... }:
{
  flake.modules.nixos.vscode = {
    home-manager.sharedModules = [ config.flake.modules.homeManager.vscode ];
  };

  flake.modules.homeManager.vscode = { config, osConfig, lib, pkgs, ... }: {
    home.packages = with pkgs; [
      vscode-extensions.github.copilot
      prettypst
    ];

    programs.vscode = {
      enable = true;
      profiles.default = lib.mkForce {
        extensions = with pkgs.vscode-extensions; [
          github.copilot

          redhat.java
          vscjava.vscode-java-pack

          catppuccin.catppuccin-vsc

          bierner.markdown-mermaid

          arrterian.nix-env-selector
          jnoortheen.nix-ide

          james-yu.latex-workshop
          tecosaur.latex-utilities

          myriad-dreamin.tinymist

          vue.volar
          hediet.vscode-drawio
        ];
      };
    };

    # edited from inside VS Code, so linked rather than generated
    xdg.configFile."Code/User/settings.json".source = config.lib.file.mkOutOfStoreSymlink (osConfig.my.live ./settings.json);
  };
}
